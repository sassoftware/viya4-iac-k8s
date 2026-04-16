#!/usr/bin/env bash

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# oIFS="$IFS"; IFS=" ," ; set -- $1 ; IFS="$oIFS"

# Catch errors
set -e

# Global variables
BASEDIR="$(pwd)"
BINDIR="$BASEDIR/bin"

# Determine deployment type.
# Priority: --type <value> flag > DEPLOYMENT_TYPE env var > bare_metal default
#
#   Option 1 (flag):    ./oss-k8s.sh --type azure apply setup install
#   Option 2 (env var): DEPLOYMENT_TYPE=azure ./oss-k8s.sh apply setup install
#   Option 3 (default): bare_metal
#
SYSTEM="${DEPLOYMENT_TYPE:-bare_metal}"
ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--type" ]]; then
    _next_is_type=1
  elif [[ -n "${_next_is_type:-}" ]]; then
    SYSTEM="$arg"
    unset _next_is_type
  else
    ARGS+=("$arg")
  fi
done

# Validate deployment type
if [[ "$SYSTEM" != "bare_metal" && "$SYSTEM" != "vsphere" && "$SYSTEM" != "azure" ]]; then
  echo "ERROR: Deployment type '$SYSTEM' is invalid. Valid values: bare_metal, vsphere, azure"
  echo "  Set via: ./oss-k8s.sh --type azure <actions>"
  echo "       or: DEPLOYMENT_TYPE=azure ./oss-k8s.sh <actions>"
  exit 1
fi

echo "INFO: Deployment type: $SYSTEM"

# Flags
creation_flag=false
update_flag=false
destruction_flag=false
external_flag=false
validated_args=null

# Determine how the script is being run -- natively or inside a Docker container
if [[ "$IAC_TOOLING" == "docker" ]]; then
  WORKDIR="/workspace"
  K8S_TOOL_BASE="/viya4-iac-k8s"
else
  WORKDIR="$BASEDIR"
  K8S_TOOL_BASE="$WORKDIR"
fi

# Select tfvars file based on deployment type
if [[ "$SYSTEM" == "azure" ]]; then
  TFVARS="$WORKDIR/terraform-azure.tfvars"
else
  TFVARS="$WORKDIR/terraform.tfvars"
fi
TFSTATE="$WORKDIR/terraform.tfstate"
ANSIBLE_INVENTORY="$WORKDIR/inventory"
ANSIBLE_VARS="@$WORKDIR/ansible-vars.yaml"

# Functions

# Activate vsphere Terraform configuration for vsphere deployments.
# vsphere_compute.tf.disabled holds all vsphere data sources, module calls,
# provider block, and required_providers entry. Copying it to vsphere_compute.tf
# makes Terraform see vsphere resources. Removing it for azure/bare_metal means
# Terraform never initialises a vsphere connection.
setup_providers() {
  local vsphere_active="$BASEDIR/vsphere_compute.tf"
  local vsphere_disabled="$BASEDIR/vsphere_compute.tf.disabled"
  local lock_file="$BASEDIR/.terraform.lock.hcl"

  if [[ "$SYSTEM" == "vsphere" ]]; then
    if [[ ! -f "$vsphere_disabled" ]]; then
      echo "ERROR: $vsphere_disabled not found. Cannot enable vsphere deployment."
      exit 1
    fi
    cp "$vsphere_disabled" "$vsphere_active"
    echo "INFO: vSphere provider and resources enabled."
  else
    # Remove vsphere compute file and stale lock entry so terraform init is clean
    if [[ -f "$vsphere_active" ]]; then
      rm -f "$vsphere_active"
      if [[ -f "$lock_file" ]] && grep -q 'vsphere' "$lock_file" 2>/dev/null; then
        rm -f "$lock_file"
        echo "INFO: Lock file cleared (stale vsphere entry removed)."
      fi
      echo "INFO: vSphere resources deactivated for $SYSTEM deployment."
    fi
    # Also clean up the old provider_vsphere_active.tf from previous approach
    rm -f "$BASEDIR/provider_vsphere_active.tf"
  fi
}

# vSphere credential gathering
gather_vsphere_creds() {
    if [[ -z "$VSPHERE_USER" ]]; then
        read -p 'vsphere_user: ' VSPHERE_USER
    fi
    echo

    if [[ -z "$VSPHERE_PASSWORD" ]]; then
        read -sp 'vsphere_password: ' VSPHERE_PASSWORD
    fi
    echo

    export TF_VAR_vsphere_user=$VSPHERE_USER
    export TF_VAR_vsphere_password=$VSPHERE_PASSWORD
    export TF_VAR_ansible_user=$ANSIBLE_USER
    export TF_VAR_ansible_password=$ANSIBLE_PASSWORD
}

# Azure credential gathering
# Azure credentials can be provided via env vars (ARM_SUBSCRIPTION_ID, ARM_TENANT_ID,
# ARM_CLIENT_ID, ARM_CLIENT_SECRET) or Managed Identity (set AZURE_USE_MSI=true).
gather_azure_creds() {
    # Check for MSI: honour AZURE_USE_MSI env var, OR detect azure_use_msi=true in tfvars
    local tfvars_msi
    tfvars_msi=$(grep -E '^\s*azure_use_msi\s*=\s*true' "$TFVARS" 2>/dev/null || true)
    if [[ "${AZURE_USE_MSI:-false}" == "true" || -n "$tfvars_msi" ]]; then
        echo "INFO: Using Managed Identity for Azure authentication."
        export TF_VAR_azure_use_msi=true
        return
    fi

    # Service Principal path: read from env vars (ARM_*) or TF_VAR_* or prompt
    if [[ -z "${TF_VAR_azure_subscription_id:-}${ARM_SUBSCRIPTION_ID:-}" ]]; then
        read -p 'azure_subscription_id: ' ARM_SUBSCRIPTION_ID
        export TF_VAR_azure_subscription_id=$ARM_SUBSCRIPTION_ID
    fi

    if [[ -z "${TF_VAR_azure_tenant_id:-}${ARM_TENANT_ID:-}" ]]; then
        read -p 'azure_tenant_id: ' ARM_TENANT_ID
        export TF_VAR_azure_tenant_id=$ARM_TENANT_ID
    fi

    if [[ -z "${TF_VAR_azure_client_id:-}${ARM_CLIENT_ID:-}" ]]; then
        read -p 'azure_client_id: ' ARM_CLIENT_ID
        export TF_VAR_azure_client_id=$ARM_CLIENT_ID
    fi

    if [[ -z "${TF_VAR_azure_client_secret:-}${ARM_CLIENT_SECRET:-}" ]]; then
        read -sp 'azure_client_secret: ' ARM_CLIENT_SECRET
        echo
        export TF_VAR_azure_client_secret=$ARM_CLIENT_SECRET
    fi

    # Export ARM_* aliases so the azurerm provider picks them up too
    export ARM_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID:-$TF_VAR_azure_subscription_id}
    export ARM_TENANT_ID=${ARM_TENANT_ID:-$TF_VAR_azure_tenant_id}
    export ARM_CLIENT_ID=${ARM_CLIENT_ID:-$TF_VAR_azure_client_id}
    export ARM_CLIENT_SECRET=${ARM_CLIENT_SECRET:-$TF_VAR_azure_client_secret}
}

terraform_prep() {
  setup_providers
  if [[ "$SYSTEM" == "vsphere" ]]; then
    gather_vsphere_creds
  elif [[ "$SYSTEM" == "azure" ]]; then
    gather_azure_creds
  fi
  terraform init
}

terraform_up() {
    terraform_prep
    terraform apply -parallelism=20 -state $TFSTATE -auto-approve -var "deployment_type=$SYSTEM" -var-file $TFVARS
    echo "Wait for OS startup - Sleeping for 60 seconds"
    sleep 60
}

terraform_down() {
    terraform_prep
    terraform destroy -parallelism=20 -state $TFSTATE -auto-approve -var "deployment_type=$SYSTEM" -var-file $TFVARS
}

# bare_metal items (ansible)
gather_ans_creds() {
    if [[ -z "$ANSIBLE_USER" ]]; then 
        read -p 'ansible_user: ' ANSIBLE_USER
    fi
    echo

    if [[ -z "$ANSIBLE_PASSWORD" ]]; then 
        read -sp 'ansible_password: ' ANSIBLE_PASSWORD
    fi
    echo
}

# vSphere and bare-metal items
ansible_prep() {
    gather_ans_creds
    ansible-galaxy collection install -r "$BASEDIR/requirements.yaml"
}

clean_up() {
    rm -rf $WORKDIR/*-oss-kubeconfig.conf
    rm -rf $WORKDIR/sas-iac-buildinfo-cm.yaml
}

help() {
  echo ""
  echo "Usage: $0 [--type <deployment_type>] [apply|setup|install|update|uninstall|cleanup|destroy|helm|k|tf]"
  echo ""
  echo "  Deployment Type - Specify with --type flag or DEPLOYMENT_TYPE env var (default: bare_metal)"
  echo ""
  echo "    --type bare_metal   Physical/manually provisioned servers (Ansible only)"
  echo "    --type vsphere      VMware vSphere/vCenter               (Terraform + Ansible)"
  echo "    --type azure        Microsoft Azure VMs                  (Terraform + Ansible)"
  echo ""
  echo "  Examples:"
  echo "    $0 --type azure   apply setup install"
  echo "    $0 --type vsphere apply setup install"
  echo "    DEPLOYMENT_TYPE=azure $0 apply setup install"
  echo "    $0 setup install                           # bare_metal (default)"
  echo ""
  echo "  Actions           - Items and their meanings"
  echo ""
  echo "    apply           - IaC creation                     : vsphere, azure"
  echo "    setup           - System and software setup        : all types"
  echo "    install         - Kubernetes install               : all types"
  echo "    update          - System and/or Kubernetes updates : all types"
  echo "    uninstall       - Kubernetes uninstall             : all types"
  echo "    cleanup         - System and software cleanup      : all types"
  echo "    destroy         - IaC destruction                  : vsphere, azure"
  echo ""
  echo "  Action groupings  - These items can be run together."
  echo "                      Alternate combinations are not allowed."
  echo ""
  echo "  creation items    - [apply setup install]"
  echo "  update items      - [update]"
  echo "  destruction items - [uninstall cleanup destroy]"
  echo ""
  echo "  Tooling - Integrated tools"
  echo ""
  echo "    helm            - Helm                             : kubernetes"
  echo "    k               - kubectl                          : kubernetes"
  echo "    tf              - Terraform                        : vsphere, azure"
  echo ""
  echo "  Examples:"
  echo "    DEPLOYMENT_TYPE=azure   $0 apply setup install"
  echo "    DEPLOYMENT_TYPE=vsphere $0 apply setup install"
  echo "    DEPLOYMENT_TYPE=azure   $0 uninstall cleanup destroy"
  echo "                    $0 setup install          # bare_metal (default)"
  echo ""
  exit 1
}

# Process input
if [ "$#" -eq 0 ]; then
  help
fi

# Processing command line arguments
#
# Actions are:
#
#   apply     - IaC creation
#   setup     - System and software setup
#   install   - Kubernetes install
#   update    - System and/or Kubernetes update
#   uninstall - Kubernetes uninstall
#   cleanup   - System and software cleanup
#   destroy   - IaC Destruction
#


# Determine what arguments have been passed and store
# those values in a known order
for arg in ${ARGS[@]}; do
  if [[ "$arg" == "apply" ]]; then
    arguments[0]=apply
  fi
  if [[ "$arg" == "setup" ]]; then
    arguments[1]=setup
  fi
  if [[ "$arg" == "install" ]]; then
    arguments[2]=install
  fi
  if [[ "$arg" == "update" ]]; then
    arguments[3]=update
  fi
  if [[ "$arg" == "uninstall" ]]; then
    arguments[4]=uninstall
  fi
  if [[ "$arg" == "cleanup" ]]; then
    arguments[5]=cleanup
  fi
  if [[ "$arg" == "destroy" ]]; then
    arguments[6]=destroy
  fi
done

#
# Check on argument combinations
#
#  apply,setup,install       - valid
#  update                    - valid
#  uninstall,cleanup,destroy - valid
#
# No other combinations are allowed
#
creation_items=( apply setup install )
update_items=( update )
destruction_items=( uninstall cleanup destroy )
external_items=( k tf helm )

for item in ${arguments[@]}; do
  if [[ " ${creation_items[*]} " =~ " $item " ]]; then
    creation_flag=true
  fi
  if [[ " ${update_items[*]} " =~ " $item " ]]; then
    update_flag=true
  fi
  if [[ " ${destruction_items[*]} " =~ " $item " ]]; then
    destruction_flag=true
  fi
done

for item in ${ARGS[@]}; do
  if [[ " ${external_items[*]} " =~ " $item " ]]; then
    external_flag=true
  fi
done

# Validating argument combinations
if [ "$creation_flag" = true ]; then
  if [ "$update_flag" = true ] || [ "$destruction_flag" = true ]; then
    validated_args=false
  else
    validated_args=true
  fi
fi

if [ "$update_flag" = true ]; then
  if [ "$creation_flag" = true ] || [ "$destruction_flag" = true ]; then
    validated_args=false
  else
    validated_args=true
  fi
fi

if [ "$destruction_flag" = true ]; then
  if [ "$creation_flag" = true ] || [ "$update_flag" = true ]; then
    validated_args=false
  else
    validated_args=true
  fi
fi

if [ "$external_flag" = true ]; then
  if [ "$creation_flag" = true ] || [ "$update_flag" = true ] || [ "$destruction_flag" = true ]; then
    validated_args=false
  else
    validated_args=true
  fi
fi

if [ "$validated_args" != true ]; then
  echo "The arguments and/or combination of arguments is invalid: $ARGS"
  echo ""
  help
fi

if [ "$external_flag" = true ] && [ "$validated_args" = true ]; then
  # Check to see if the request is for tooling help
  while [ "${#ARGS[@]}" -gt 0 ]; do
    case "$1" in
      helm )
        helm ${@:2}
        exit "$?"
        ;;
      k|kubtctl )
        kubectl ${@:2}
        exit "$?"
        ;;
      tf|terraform )
        terraform $2 -state $TFSTATE ${@:3}
        exit "$?"
        ;;
    esac
  done    
fi

# Process the arguments
for item in "${arguments[@]}"; do
  # apply - Create infrastructure
  if [[ "$item" == "apply" ]]; then
    if [[ "$SYSTEM" == "bare_metal" ]]; then
      echo "INFO: bare_metal deployment does not require infrastructure provisioning. Skipping apply."
    else
      echo "Infrastructure - Virtual hardware ($SYSTEM)"
      terraform_up
    fi
  fi
  # setup - Baseline systems
  if [[ "$item" == "setup" ]]; then
    ansible_prep
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "deployment_type=$SYSTEM" --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/systems-install.yaml --flush-cache --tags install
  fi
  # install - Install kubernetes
  if [[ "$item" == "install" ]]; then
    ansible_prep
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "deployment_type=$SYSTEM" --extra-vars "iac_tooling=$IAC_TOOLING" --extra-vars "iac_inventory_dir=$WORKDIR" --extra-vars "k8s_tool_base"=$K8S_TOOL_BASE --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/kubernetes-install.yaml --flush-cache --tags install
  fi
  # update- Update systems and/or kubernetes
  if [[ "$item" == "update" ]]; then
    echo "TODO: update"
  fi
  # uninstall - Uninstall kubernetes
  if [[ "$item" == "uninstall" ]]; then
    ansible_prep
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "deployment_type=$SYSTEM" --extra-vars "iac_tooling=$IAC_TOOLING" --extra-vars "iac_inventory_dir=$WORKDIR" --extra-vars "k8s_tool_base"=$K8S_TOOL_BASE --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/kubernetes-uninstall.yaml --flush-cache --tags uninstall
    rm -rf *-oss-kubeconfig.conf 2>&1 > /dev/null
    rm -rf sas-iac-buildinfo-cm.yaml 2>&1 > /dev/null
  fi
  # cleanup - 
  if [[ "$item" == "cleanup" ]]; then
    echo "TODO: cleanup"
  fi
  # destroy - Destroy infrastructure
  if [[ "$item" == "destroy" ]]; then
    if [[ "$SYSTEM" == "bare_metal" ]]; then
      echo "INFO: bare_metal deployment has no infrastructure to destroy."
      break
    fi
    if [[ -e $TFSTATE ]]; then
      if [[ "$IAC_TOOLING" != "docker" ]]; then
        read -p 'Are you absolutely sure: ' CONFIRMATION
        if [[ "$CONFIRMATION" == "y" || "$CONFIRMATION" == "yes" ]]; then
          echo "Destroying cluster and infra"
          terraform_down
        else
          echo "You did not opt to run destroy"
          exit 1
        fi
      else
        echo "Destroying cluster and infra"
        terraform_down
      fi
    else
      echo "No infrastructure to destroy. Thanks for playing ;)"
      exit 0
    fi
    # Clean up
    clean_up
    rm -rf "$TFSTATE" 2>&1 > /dev/null
    rm -rf "$TFSTATE.backup" 2>&1 > /dev/null
    rm -rf $BASEDIR/ssl-cert-sas-*-pgsql.{key,pem} 2>&1 > /dev/null
    break
  fi
done

# while [ "$#" -gt 0 ]; do
#   case "$1" in
#     helm )
#       helm ${@:2}
#       break
#       ;;
#     k|kubtctl )
#       kubectl ${@:2}
#       break
#       ;;
#     tf|terraform )
#       terraform $2 -state $TFSTATE ${@:3}
#       break
#       ;;
#     * )
#       echo "Please enter the correct arguments."
#       break
#       ;;
#   esac
# done

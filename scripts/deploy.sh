#!/usr/bin/env bash

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Azure-only deployment script for viya4-iac-k8s-azure

set -e

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM="azure"
TOPOLOGY_DIR="$BASEDIR/topologies/$SYSTEM"

if [[ "$IAC_TOOLING" == "docker" ]]; then
  WORKDIR="/workspace"
  K8S_TOOL_BASE="/viya4-iac-k8s"
else
  WORKDIR="$BASEDIR"
  K8S_TOOL_BASE="$WORKDIR"
fi

TFVARS="$WORKDIR/terraform-azure.tfvars"
TFSTATE="$WORKDIR/terraform.tfstate"
# Inventory and vars are written by Terraform to TOPOLOGY_DIR (via -chdir).
# Reading from TOPOLOGY_DIR ensures Ansible also loads group_vars/ from that directory.
ANSIBLE_INVENTORY="$TOPOLOGY_DIR/inventory"
ANSIBLE_VARS="@$TOPOLOGY_DIR/ansible-vars.yaml"

# Shared utility functions: gather_ans_creds, clean_up
# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# Ansible role search: topology-specific roles first, then shared roles at repo root.
export ANSIBLE_ROLES_PATH="$TOPOLOGY_DIR/roles:$BASEDIR/roles"

gather_azure_creds() {
    local tfvars_msi
    tfvars_msi=$(grep -E '^\s*azure_use_msi\s*=\s*true' "$TFVARS" 2>/dev/null || true)
    if [[ "${AZURE_USE_MSI:-false}" == "true" || -n "$tfvars_msi" ]]; then
        echo "INFO: Using Managed Identity for Azure authentication."
        export TF_VAR_azure_use_msi=true
        return
    fi

    if [[ -z "${TF_VAR_azure_subscription_id:-}${ARM_SUBSCRIPTION_ID:-}" ]]; then
        read -rp 'azure_subscription_id: ' ARM_SUBSCRIPTION_ID
        export TF_VAR_azure_subscription_id=$ARM_SUBSCRIPTION_ID
    fi
    if [[ -z "${TF_VAR_azure_tenant_id:-}${ARM_TENANT_ID:-}" ]]; then
        read -rp 'azure_tenant_id: ' ARM_TENANT_ID
        export TF_VAR_azure_tenant_id=$ARM_TENANT_ID
    fi
    if [[ -z "${TF_VAR_azure_client_id:-}${ARM_CLIENT_ID:-}" ]]; then
        read -rp 'azure_client_id: ' ARM_CLIENT_ID
        export TF_VAR_azure_client_id=$ARM_CLIENT_ID
    fi
    if [[ -z "${TF_VAR_azure_client_secret:-}${ARM_CLIENT_SECRET:-}" ]]; then
        read -rsp 'azure_client_secret: ' ARM_CLIENT_SECRET
        echo
        export TF_VAR_azure_client_secret=$ARM_CLIENT_SECRET
    fi

    export ARM_SUBSCRIPTION_ID=${ARM_SUBSCRIPTION_ID:-$TF_VAR_azure_subscription_id}
    export ARM_TENANT_ID=${ARM_TENANT_ID:-$TF_VAR_azure_tenant_id}
    export ARM_CLIENT_ID=${ARM_CLIENT_ID:-$TF_VAR_azure_client_id}
    export ARM_CLIENT_SECRET=${ARM_CLIENT_SECRET:-$TF_VAR_azure_client_secret}
}

terraform_prep() {
    gather_azure_creds
    terraform -chdir="$TOPOLOGY_DIR" init
}

terraform_up() {
    terraform_prep
    terraform -chdir="$TOPOLOGY_DIR" apply -parallelism=20 -state "$TFSTATE" -auto-approve -var-file "$TFVARS"
    echo "Wait for OS startup - Sleeping for 60 seconds"
    sleep 60
}

terraform_down() {
    terraform_prep
    terraform -chdir="$TOPOLOGY_DIR" destroy -parallelism=20 -state "$TFSTATE" -auto-approve -var-file "$TFVARS"
}

ansible_prep() {
    gather_ans_creds
    ansible-galaxy collection install -r "$BASEDIR/requirements.yml"
}

help() {
  echo ""
  echo "Usage: $0 [apply|setup|install|update|uninstall|cleanup|destroy|helm|k|tf]"
  echo ""
  echo "  Actions"
  echo "    apply     - Azure infrastructure creation"
  echo "    setup     - System and software setup"
  echo "    install   - Kubernetes install"
  echo "    update    - System and/or Kubernetes updates"
  echo "    uninstall - Kubernetes uninstall"
  echo "    cleanup   - System and software cleanup"
  echo "    destroy   - Azure infrastructure destruction"
  echo ""
  echo "  Examples:"
  echo "    $0 apply setup install"
  echo "    $0 uninstall cleanup destroy"
  echo ""
  exit 1
}

if [ "$#" -eq 0 ]; then
  help
fi

for arg in "$@"; do
  if [[ "$arg" == "apply" ]];     then arguments[0]=apply;     fi
  if [[ "$arg" == "setup" ]];     then arguments[1]=setup;     fi
  if [[ "$arg" == "install" ]];   then arguments[2]=install;   fi
  if [[ "$arg" == "update" ]];    then arguments[3]=update;    fi
  if [[ "$arg" == "uninstall" ]]; then arguments[4]=uninstall; fi
  if [[ "$arg" == "cleanup" ]];   then arguments[5]=cleanup;   fi
  if [[ "$arg" == "destroy" ]];   then arguments[6]=destroy;   fi
done

creation_items=( apply setup install )
update_items=( update )
destruction_items=( uninstall cleanup destroy )
external_items=( k tf helm )

for item in "${arguments[@]}"; do
  if [[ " ${creation_items[*]} " =~ " $item " ]];    then creation_flag=true;    fi
  if [[ " ${update_items[*]} " =~ " $item " ]];      then update_flag=true;      fi
  if [[ " ${destruction_items[*]} " =~ " $item " ]]; then destruction_flag=true; fi
done

for item in "$@"; do
  if [[ " ${external_items[*]} " =~ " $item " ]]; then external_flag=true; fi
done

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
  echo "The arguments and/or combination of arguments is invalid: $*"
  echo ""
  help
fi

if [ "$external_flag" = true ] && [ "$validated_args" = true ]; then
  case "$1" in
    helm )    helm "${@:2}"; exit "$?" ;;
    k|kubectl ) kubectl "${@:2}"; exit "$?" ;;
    tf|terraform ) terraform "$2" -state "$TFSTATE" "${@:3}"; exit "$?" ;;
  esac
fi

for item in "${arguments[@]}"; do
  if [[ "$item" == "apply" ]]; then
    echo "Infrastructure - Azure Virtual Machines"
    terraform_up
  fi
  if [[ "$item" == "setup" ]]; then
    ansible_prep
    ANSIBLE_CONFIG="$TOPOLOGY_DIR/ansible.cfg" ansible-playbook \
      -i "$ANSIBLE_INVENTORY" \
      --extra-vars "deployment_type=$SYSTEM" \
      --extra-vars "$ANSIBLE_VARS" \
      "$TOPOLOGY_DIR/playbooks/systems-install.yaml" \
      --flush-cache --tags install
  fi
  if [[ "$item" == "install" ]]; then
    ansible_prep
    ANSIBLE_CONFIG="$TOPOLOGY_DIR/ansible.cfg" ansible-playbook \
      -i "$ANSIBLE_INVENTORY" \
      --extra-vars "deployment_type=$SYSTEM" \
      --extra-vars "iac_tooling=$IAC_TOOLING" \
      --extra-vars "iac_inventory_dir=$WORKDIR" \
      --extra-vars "k8s_tool_base=$K8S_TOOL_BASE" \
      --extra-vars "$ANSIBLE_VARS" \
      "$TOPOLOGY_DIR/playbooks/kubernetes-install.yaml" \
      --flush-cache --tags install
  fi
  if [[ "$item" == "update" ]]; then
    echo "TODO: update"
  fi
  if [[ "$item" == "uninstall" ]]; then
    ansible_prep
    ANSIBLE_CONFIG="$TOPOLOGY_DIR/ansible.cfg" ansible-playbook \
      -i "$ANSIBLE_INVENTORY" \
      --extra-vars "deployment_type=$SYSTEM" \
      --extra-vars "iac_tooling=$IAC_TOOLING" \
      --extra-vars "iac_inventory_dir=$WORKDIR" \
      --extra-vars "k8s_tool_base=$K8S_TOOL_BASE" \
      --extra-vars "$ANSIBLE_VARS" \
      "$TOPOLOGY_DIR/playbooks/kubernetes-uninstall.yaml" \
      --flush-cache --tags uninstall
    clean_up
  fi
  if [[ "$item" == "cleanup" ]]; then
    echo "Running system cleanup on Azure topology"
    ansible_prep
    ANSIBLE_CONFIG="$TOPOLOGY_DIR/ansible.cfg" ansible-playbook \
      -i "$ANSIBLE_INVENTORY" \
      --extra-vars "deployment_type=$SYSTEM" \
      --extra-vars "iac_tooling=$IAC_TOOLING" \
      --extra-vars "iac_inventory_dir=$WORKDIR" \
      --extra-vars "k8s_tool_base=$K8S_TOOL_BASE" \
      --extra-vars "$ANSIBLE_VARS" \
      "$TOPOLOGY_DIR/playbooks/systems-cleanup.yaml" \
      --flush-cache --tags cleanup
    clean_up
  fi
  if [[ "$item" == "destroy" ]]; then
    if [[ -e "$TFSTATE" ]]; then
      if [[ "$IAC_TOOLING" != "docker" ]]; then
        read -rp 'Are you absolutely sure: ' CONFIRMATION
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
    clean_up
    rm -rf "$TFSTATE" 2>/dev/null || true
    rm -rf "$TFSTATE.backup" 2>/dev/null || true
    break
  fi
done

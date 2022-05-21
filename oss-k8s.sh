#!/usr/bin/env bash
# oIFS="$IFS"; IFS=" ," ; set -- $1 ; IFS="$oIFS"

# Catch errors
set -e

# Global variables
ARGS="$@"
BASEDIR="$(pwd)"
BINDIR="$BASEDIR/bin"
SYSTEM="bare_metal"

# Flags
creation_flag=false
update_flag=false
destruction_flag=false
external_flag=false
validated_args=null

# Determine how the script is being run native or inside a docker container
if [[ "$IAC_TOOLING" == "docker" ]]; then
  TFVARS="/workspace/terraform.tfvars"
  TFSTATE="/workspace/terraform.tfstate"
  ANSIBLE_INVENTORY_DIR="/workspace"
  ANSIBLE_INVENTORY="$ANSIBLE_INVENTORY_DIR/inventory"
  ANSIBLE_VARS="@/workspace/ansible-vars.yaml"
  K8S_TOOL_BASE="/viya4-iac-k8s"
else
  TFVARS="$BASEDIR/terraform.tfvars"
  TFSTATE="$BASEDIR/terraform.tfstate"
  ANSIBLE_INVENTORY_DIR="$BASEDIR"
  ANSIBLE_INVENTORY="$ANSIBLE_INVENTORY_DIR/inventory"
  ANSIBLE_VARS="@$BASEDIR/ansible-vars.yaml"
  K8S_TOOL_BASE="$BASEDIR"
fi

# Functions

# vSphere items (terraform)
gather_tf_creds() {
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

terraform_prep() {
  gather_tf_creds
  terraform init
}

terraform_up() {
    terraform_prep
    terraform apply -parallelism=15 -state $TFSTATE -auto-approve -var "deployment_type=$SYSTEM" -var-file $TFVARS
    echo "Wait for OS startup - Sleeping for 45 seconds"
    sleep 45
}

terraform_down() {
    terraform_prep
    terraform destroy -parallelism=15 -state $TFSTATE -auto-approve -var "deployment_type=$SYSTEM" -var-file $TFVARS
    clean_up
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
    ansible-galaxy collection install -r "$BASEDIR/requirements.yaml" -f
}

clean_up() {
    rm -rf $ANSIBLE_INVENTORY_DIR/*-oss-kubeconfig.conf
    rm -rf $ANSIBLE_INVENTORY_DIR/sas-iac-buildinfo-cm.yaml
}

help() {
  echo ""
  echo "Usage: $0 [apply|setup|install|update|uninstall|cleanup|destroy]"
  echo ""
  echo "  Actions - Items and there meanings."
  echo ""
  echo "    apply     - IAC Creation                     : vSphere/vCenter"
  echo "    setup     - System and software setup        : systems"
  echo "    install   - Kubernetes install               : systems"
  echo "    update    - System and/or Kubernetes updates : systems"
  echo "    uninstall - Kubernetes uninstall             : systems"
  echo "    cleanup   - Systems and software cleanup     : systems"
  echo "    destroy   - IAC descrution                   : vSphere/vCenter"
  echo ""
  echo "  Action groupings  - These items can be run together."
  echo "                      Alternate combinations are not allowed."
  echo ""
  echo "  creation items    - [apply setup install]"
  echo "  update items      - [update]"
  echo "  destruction items - [uninstall cleanup destroy]"
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
#   apply     - IAC creation
#   setup     - System and software setup
#   install   - Kubernetes install
#   update    - System and/or Kubernetes update
#   uninstall - Kubernetes uninstall
#   cleanup   - System and software cleanup
#   destroy   - IAC Destruction
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

# Process the arguments
for item in "${arguments[@]}"; do
  # apply - Create infrastructure
  if [[ "$item" == "apply" ]]; then
    echo "Infrastructure - Virtual hardware"
    SYSTEM=vsphere
    terraform_up
  fi
  # setup - Baseline systems
  if [[ "$item" == "setup" ]]; then
    ansible_prep
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/systems-install.yaml --flush-cache --tags install
  fi
  # install - Install kubernetes
  if [[ "$item" == "install" ]]; then
    ansible_prep
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "iac_tooling=$IAC_TOOLING" --extra-vars "iac_inventory_dir=$ANSIBLE_INVENTORY_DIR" --extra-vars "k8s_tool_base"=$K8S_TOOL_BASE --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/kubernetes-install.yaml --flush-cache --tags install
  fi
  # update- Update systems and/or kubernetes
  if [[ "$item" == "update" ]]; then
    echo "update"
  fi
  # uninstall - Uninstall kubernetes
  if [[ "$item" == "uninstall" ]]; then
    ansible_prep
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "iac_tooling=$IAC_TOOLING" --extra-vars "iac_inventory_dir=$ANSIBLE_INVENTORY_DIR" --extra-vars "k8s_tool_base"=$K8S_TOOL_BASE --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/kubernetes-uninstall.yaml --flush-cache --tags uninstall
  fi
  # cleanup - 
  if [[ "$item" == "cleanup" ]]; then
    echo "cleanup"
  fi
  # destroy - Destroy infrastructure
  if [[ "$item" == "destroy" ]]; then
    SYSTEM=vsphere
    if [[ -e $TFSTATE ]]; then
      if [[ "$IAC_TOOLING" != "docker" ]]; then
        read -p 'Are you absolutely sure: ' CONFIRMATION
        if [[ "$CONFIRMATION" == "y" || "$CONFIRMATION" == "yes" ]]; then
          echo "Destorying cluster and infra"
          terraform_down
          break
        fi
      else
        echo "Destorying cluster and infra"
        terraform_down
        break
      fi
    else
      echo "No infrastructure to destroy. Thanks for playing ;)"
      exit 0
    fi
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

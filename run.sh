#!/usr/bin/env bash

# Catch errors
set -e

# Global variables
BASEDIR="$(pwd)"
BINDIR="$BASEDIR/bin"
ACTION=""
SYSTEM=""

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

ansible_down() {
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "deployment_type=$SYSTEM" --extra-vars "iac_tooling=$IAC_TOOLING" --extra-vars "iac_inventory_dir=$ANSIBLE_INVENTORY_DIR" --extra-vars "k8s_tool_base"=$K8S_TOOL_BASE --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/kubernetes-uninstall.yaml --flush-cache --tags uninstall
}

baseline_up() {
    # Baseline all nodes
    ansible_prep
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "deployment_type=$SYSTEM" --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/systems-install.yaml --flush-cache --tags install
    ansible-playbook -i $ANSIBLE_INVENTORY --extra-vars "deployment_type=$SYSTEM" --extra-vars "iac_tooling=$IAC_TOOLING" --extra-vars "iac_inventory_dir=$ANSIBLE_INVENTORY_DIR" --extra-vars "k8s_tool_base"=$K8S_TOOL_BASE --extra-vars $ANSIBLE_VARS $BASEDIR/playbooks/kubernetes-install.yaml --flush-cache --tags install
}

clean_up() {
    rm -rf $ANSIBLE_INVENTORY_DIR/*-oss-kubeconfig.conf
    rm -rf $ANSIBLE_INVENTORY_DIR/sas-iac-buildinfo-cm.yaml
}

help() {
  echo "Usage: $0 <action>"
  echo ""
  echo "  actions:"
  echo ""
  echo "    install [bare_metal,vsphere] - Creates vsphere infra if directed and installs kubernetes cluster"
  echo "    destroy                      - Destroys the vsphere infrastructure"
  exit 1
}

# Process input
if [ "$#" -eq 0 ]; then
  help
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      help
      break
      ;;
    install )
      if [[ "$2" == "vsphere" ]]; then
        export SYSTEM="$2"
        echo "Infrastructure - Virtual hardware"
        terraform_up
        baseline_up
        echo ""
        echo "Outputs:"
        echo ""
        terraform output -state $TFSTATE 
      elif [[ "$2" == "bare_metal" ]]; then
        export SYSTEM="$2"
        echo "Infrastrcture - Existing hardware"
        baseline_up
      else
        echo "The system type you supplied is not supported."
        echo ""
        echo "Your choices are: [bare_metal,vsphere]"
        exit 1
      fi
      break
      ;;
    update )
      echo "Updating cluster"
      ansible_up
      echo "Outputs:"
      echo ""
      terraform output -state $TFSTATE 
      break
      ;;
    uninstall )
      echo "Uninstalling cluster"
      ansible_down
      echo "Outputs:"
      echo ""
      terraform output -state $TFSTATE
      break
      ;;
    destroy )
      # Only works if the system type was vsphere which creates a tfstate file
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
      break
      ;;
    helm )
      helm ${@:2}
      break
      ;;
    k|kubtctl )
      kubectl ${@:2}
      break
      ;;
    tf|terraform )
      terraform $2 -state $TFSTATE ${@:3}
      break
      ;;
    * )
      echo "Please enter the correct arguments."
      break
      ;;
  esac
done

#!/usr/bin/env bash

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# oss-k8s.sh — OpenStack (HPOS) and bare-metal deployment script for viya4-iac-k8s.
#
# Usage:
#   SYSTEM=openstack ./scripts/oss-k8s.sh [apply] [setup] [install] [uninstall] [destroy]
#   SYSTEM=bare_metal ./scripts/oss-k8s.sh [setup] [install] [uninstall]
#
# Environment variables:
#   SYSTEM          - Deployment type: openstack or bare_metal (default: bare_metal)
#   IAC_TOOLING     - Set to "docker" when running inside the container
#   ANSIBLE_USER    - Ansible SSH username (prompted if not set)
#   ANSIBLE_PASSWORD - Ansible SSH password (prompted if not set)
#   OS_AUTH_URL, OS_USERNAME, OS_PASSWORD, etc. - Standard OpenStack RC variables

set -e

ARGS="$*"
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM="${SYSTEM:-bare_metal}"

# Determine run context: native or Docker container
if [[ "$IAC_TOOLING" == "docker" ]]; then
  WORKDIR="/workspace"
  K8S_TOOL_BASE="/viya4-iac-k8s"
else
  WORKDIR="$BASEDIR"
  K8S_TOOL_BASE="$WORKDIR"
fi

TFVARS="$WORKDIR/terraform.tfvars"
TFSTATE="$WORKDIR/terraform.tfstate"
ANSIBLE_INVENTORY="$WORKDIR/inventory"
ANSIBLE_VARS="@$WORKDIR/ansible-vars.yaml"

# Set ANSIBLE_CONFIG and ANSIBLE_ROLES_PATH from the active topology directory.
# This replaces the old approach of baking a single ansible.cfg path in the image
# and the write_provider_config / write_main_config runtime file-mutation hacks.
TOPOLOGY_DIR="$BASEDIR/topologies/$SYSTEM"
export ANSIBLE_CONFIG="$TOPOLOGY_DIR/ansible.cfg"
export ANSIBLE_ROLES_PATH="$TOPOLOGY_DIR/roles:$BASEDIR/roles"

# Shared utility functions: gather_ans_creds, clean_up
# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

TF_COMPAT_ARGS=()

# =============================================================================
# Credential helpers
# =============================================================================

gather_tf_creds() {
  if [[ "$SYSTEM" == "openstack" ]]; then
    # Auto-source the standard creds file if present and env isn't already populated
    if [[ -f "$HOME/.openstack_creds.env" ]] && [[ -z "$OS_AUTH_URL" ]]; then
      set -a
      # shellcheck source=/dev/null
      source "$HOME/.openstack_creds.env"
      set +a
    fi

    if [[ -z "$OS_USERNAME" ]]; then
      read -rp 'openstack_user_name: ' OS_USERNAME
    fi
    if [[ -z "$OS_PASSWORD" ]]; then
      read -rsp 'openstack_password: ' OS_PASSWORD
      echo
    fi

    export TF_VAR_openstack_user_name=$OS_USERNAME
    export TF_VAR_openstack_password=$OS_PASSWORD
    export TF_VAR_openstack_auth_url=${OS_AUTH_URL:-$TF_VAR_openstack_auth_url}
    export TF_VAR_openstack_tenant_name=${OS_PROJECT_NAME:-$TF_VAR_openstack_tenant_name}
    export TF_VAR_openstack_domain_name=${OS_USER_DOMAIN_NAME:-$TF_VAR_openstack_domain_name}
    export TF_VAR_openstack_region=${OS_REGION_NAME:-$TF_VAR_openstack_region}
    export TF_VAR_openstack_insecure=${OS_INSECURE:-true}
  fi

  if [[ "$SYSTEM" == "vsphere" ]]; then
    if [[ -z "${VSPHERE_SERVER:-$TF_VAR_vsphere_server}" ]]; then
      read -rp 'vsphere_server: ' VSPHERE_SERVER
    fi
    if [[ -z "${VSPHERE_USER:-$TF_VAR_vsphere_user}" ]]; then
      read -rp 'vsphere_user: ' VSPHERE_USER
    fi
    if [[ -z "${VSPHERE_PASSWORD:-$TF_VAR_vsphere_password}" ]]; then
      read -rsp 'vsphere_password: ' VSPHERE_PASSWORD
      echo
    fi
    export TF_VAR_vsphere_server=${VSPHERE_SERVER:-$TF_VAR_vsphere_server}
    export TF_VAR_vsphere_user=${VSPHERE_USER:-$TF_VAR_vsphere_user}
    export TF_VAR_vsphere_password=${VSPHERE_PASSWORD:-$TF_VAR_vsphere_password}
  fi

  if [[ -n "$ANSIBLE_USER"     ]]; then export TF_VAR_ansible_user=$ANSIBLE_USER; fi
  if [[ -n "$ANSIBLE_PASSWORD" ]]; then export TF_VAR_ansible_password=$ANSIBLE_PASSWORD; fi
}

# =============================================================================
# Terraform helpers
# =============================================================================

terraform_prep() {
  gather_tf_creds
  terraform -chdir="$TOPOLOGY_DIR" init
}

terraform_up() {
  terraform_prep
  # Always pass absolute paths for inventory and ansible_vars so the local_file
  # resources write to $WORKDIR (repo root) regardless of -chdir topology dir.
  local TF_OUTPUT_ARGS=(
    -var "inventory=$WORKDIR/inventory"
    -var "ansible_vars=$WORKDIR/ansible-vars.yaml"
  )
  terraform -chdir="$TOPOLOGY_DIR" apply \
    -parallelism=20 \
    -state "$TFSTATE" \
    -auto-approve \
    "${TF_OUTPUT_ARGS[@]}" \
    -var-file "$TFVARS"
  echo "Wait for OS startup - Sleeping for 60 seconds"
  sleep 60
  if [[ "$SYSTEM" == "openstack" ]]; then
    patch_vip_allowed_pairs
  fi
}

terraform_down() {
  terraform_prep
  # Always pass absolute paths for inventory and ansible_vars.
  local TF_OUTPUT_ARGS=(
    -var "inventory=$WORKDIR/inventory"
    -var "ansible_vars=$WORKDIR/ansible-vars.yaml"
  )
  terraform -chdir="$TOPOLOGY_DIR" destroy \
    -parallelism=20 \
    -state "$TFSTATE" \
    -auto-approve \
    "${TF_OUTPUT_ARGS[@]}" \
    -var-file "$TFVARS"
}

# =============================================================================
# OpenStack VIP helpers  (Task 1.10)
# =============================================================================

# allocate_vip_floating_ip — Allocate two OpenStack floating IPs:
#   1. cluster_vip_ip      — kube-vip control-plane HA VIP
#   2. cluster_lb_addresses — kube-vip cloud-provider LoadBalancer service VIP
# Each IP is only allocated if not already set in terraform.tfvars.
# The floating IPs are created unassociated (no server) — they exist solely to
# reserve clean IPs that OpenStack tracks, which can then be registered in
# names.sas.com under the unx.sas.com domain.
allocate_vip_floating_ip() {
  # openstack floating ip create requires the EXTERNAL network (floating IP pool),
  # not the internal tenant network.  Read openstack_floating_ip_pool first; fall
  # back to openstack_network_name only when the pool is explicitly null/empty.
  local NETWORK
  NETWORK=$(grep -E '^\s*openstack_floating_ip_pool\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' "')
  if [[ -z "$NETWORK" || "$NETWORK" == "null" ]]; then
    NETWORK=$(grep -E '^\s*openstack_network_name\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' "')
  fi
  if [[ -z "$NETWORK" ]]; then
    echo "allocate_vip_floating_ip: openstack_floating_ip_pool not set in $TFVARS, skipping."
    return 0
  fi

  # [1] cluster_vip_ip — control-plane HA VIP
  local CURRENT_VIP
  CURRENT_VIP=$(grep -E '^\s*cluster_vip_ip\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*//' | tr -d ' "')
  local VIP
  if [[ -n "$CURRENT_VIP" && "$CURRENT_VIP" != "null" ]]; then
    echo "allocate_vip_floating_ip: [cluster_vip_ip]      already set to $CURRENT_VIP — skipping allocation."
    VIP="$CURRENT_VIP"
  else
    echo "allocate_vip_floating_ip: allocating floating IP for cluster_vip_ip (control-plane HA VIP)..."
    local FIP_JSON1
    FIP_JSON1=$(openstack --insecure floating ip create "$NETWORK" -f json 2>/dev/null)
    VIP=$(echo "$FIP_JSON1" | python3 -c "import sys,json; print(json.load(sys.stdin).get('floating_ip_address',''))" 2>/dev/null)
    if [[ -z "$VIP" ]]; then
      echo "allocate_vip_floating_ip: failed to allocate cluster_vip_ip, skipping."
      return 0
    fi
    if grep -qE '^\s*#?\s*cluster_vip_ip\s*=' "$TFVARS"; then
      sed -i "s|^\s*#\?\s*cluster_vip_ip\s*=.*|cluster_vip_ip      = \"${VIP}\"|" "$TFVARS"
    else
      sed -i "/cluster_vip_version/a cluster_vip_ip      = \"${VIP}\"" "$TFVARS"
    fi
    echo "allocate_vip_floating_ip: [cluster_vip_ip]      allocated $VIP — written to $TFVARS"
  fi

  # [2] cluster_lb_addresses — LoadBalancer service VIP
  local CURRENT_LB
  CURRENT_LB=$(grep -E '^\s*cluster_lb_addresses\s*=' "$TFVARS" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  local LB_VIP
  if [[ -n "$CURRENT_LB" ]]; then
    echo "allocate_vip_floating_ip: [cluster_lb_addresses] already set to $CURRENT_LB — skipping allocation."
    LB_VIP="$CURRENT_LB"
  else
    echo "allocate_vip_floating_ip: allocating floating IP for cluster_lb_addresses (LoadBalancer service VIP)..."
    local FIP_JSON2
    FIP_JSON2=$(openstack --insecure floating ip create "$NETWORK" -f json 2>/dev/null)
    LB_VIP=$(echo "$FIP_JSON2" | python3 -c "import sys,json; print(json.load(sys.stdin).get('floating_ip_address',''))" 2>/dev/null)
    if [[ -z "$LB_VIP" ]]; then
      echo "allocate_vip_floating_ip: failed to allocate cluster_lb_addresses IP, skipping."
      return 0
    fi
    if grep -qE '^\s*cluster_lb_addresses\s*=' "$TFVARS"; then
      sed -i "s|^\s*cluster_lb_addresses\s*=.*|cluster_lb_addresses = [\"range-global: ${LB_VIP}-${LB_VIP}\"]|" "$TFVARS"
    else
      sed -i "/cluster_lb_type/a cluster_lb_addresses = [\"range-global: ${LB_VIP}-${LB_VIP}\"]" "$TFVARS"
    fi
    echo "allocate_vip_floating_ip: [cluster_lb_addresses] allocated $LB_VIP — written to $TFVARS"
  fi

  echo ""
  echo "  *** ACTION REQUIRED ***"
  echo "  Register both VIPs in names.sas.com (unx.sas.com domain):"
  echo "    [1] cluster_vip_ip       $VIP    ->  <prefix>-vip.unx.sas.com"
  echo "    [2] cluster_lb_addresses $LB_VIP ->  <prefix>-lb.unx.sas.com"
  echo "  Then set cluster_vip_fqdn in $TFVARS to match."
  echo "  *** ******************** ***"
  echo ""
}

# patch_vip_allowed_pairs — Add the kube-vip VIP (and LB IPs) to allowed_address_pairs
# on all Neutron ports belonging to cluster nodes.  The Neutron policy in most
# environments disallows setting allowed_address_pairs at port-creation time but
# allows PUTting them on existing ports.  This function runs after terraform_up so
# the ports already exist.
patch_vip_allowed_pairs() {
  local VIP
  VIP=$(grep -E '^\s*cluster_vip_ip\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*//' | tr -d ' "')
  if [[ -z "$VIP" || "$VIP" == "null" ]]; then
    # Fallback: resolve VIP from cluster_vip_fqdn via DNS
    local VIP_FQDN
    VIP_FQDN=$(grep -E '^\s*cluster_vip_fqdn\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*//' | tr -d ' "')
    if [[ -n "$VIP_FQDN" ]]; then
      VIP=$(getent hosts "$VIP_FQDN" 2>/dev/null | awk '{print $1}' | head -1)
      [[ -n "$VIP" ]] && echo "patch_vip_allowed_pairs: cluster_vip_ip empty, resolved ${VIP_FQDN} -> ${VIP}"
    fi
    if [[ -z "$VIP" ]]; then
      echo "patch_vip_allowed_pairs: cluster_vip_ip not set and cluster_vip_fqdn could not be resolved, skipping."
      return 0
    fi
  fi

  local NEUTRON_URL TOKEN TOKEN_RESPONSE JSON_BODY
  JSON_BODY=$(python3 -c "
import json, os
print(json.dumps({
    'auth': {
        'identity': {
            'methods': ['password'],
            'password': {
                'user': {
                    'name': os.environ.get('OS_USERNAME',''),
                    'domain': {'name': os.environ.get('OS_USER_DOMAIN_NAME','')},
                    'password': os.environ.get('OS_PASSWORD','')
                }
            }
        },
        'scope': {
            'project': {
                'name': os.environ.get('OS_PROJECT_NAME',''),
                'domain': {'name': os.environ.get('OS_PROJECT_DOMAIN_NAME',
                                   os.environ.get('OS_USER_DOMAIN_NAME',''))}
            }
        }
    }
}))
" 2>/dev/null)

  TOKEN_RESPONSE=$(curl -sk -i -X POST "${OS_AUTH_URL}auth/tokens" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY" 2>/dev/null)
  TOKEN=$(echo "$TOKEN_RESPONSE" | grep -i "x-subject-token" | awk '{print $2}' | tr -d '\r\n')
  NEUTRON_URL=$(echo "$TOKEN_RESPONSE" | python3 -c "
import sys, json
data = sys.stdin.read()
body = json.loads(data[data.find('{'):])
for svc in body.get('token',{}).get('catalog',[]):
    if svc.get('type') == 'network':
        for ep in svc.get('endpoints',[]):
            if ep.get('interface') == 'public':
                print(ep.get('url',''))
                break
" 2>/dev/null)

  if [[ -z "$TOKEN" ]] || [[ -z "$NEUTRON_URL" ]]; then
    echo "patch_vip_allowed_pairs: could not obtain Keystone token or Neutron URL, skipping."
    return 0
  fi

  local PREFIX
  PREFIX=$(grep -E '^\s*prefix\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' "')
  local CLUSTER_NAME="${PREFIX}-oss"

  # Build allowed_address_pairs: VIP + any IPs from cluster_lb_addresses ranges
  local LB_IPS=()
  while IFS= read -r lb_line; do
    local first_ip last_ip
    first_ip=$(echo "$lb_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    last_ip=$(echo "$lb_line" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
    if [[ -n "$first_ip" && -n "$last_ip" && "$first_ip" != "$last_ip" ]]; then
      local base="${first_ip%.*}" start_oct="${first_ip##*.}" end_oct="${last_ip##*.}"
      for oct in $(seq "$start_oct" "$end_oct"); do LB_IPS+=("${base}.${oct}"); done
    elif [[ -n "$first_ip" ]]; then
      LB_IPS+=("$first_ip")
    fi
  done < <(grep -E '^\s*cluster_lb_addresses' "$TFVARS" 2>/dev/null | grep -oE '"[^"]*range[^"]*"' | tr -d '"')

  local PAIRS_JSON="{\"ip_address\":\"${VIP}\"}"
  for lb_ip in "${LB_IPS[@]}"; do
    [[ "$lb_ip" == "$VIP" ]] && continue
    PAIRS_JSON+=",{\"ip_address\":\"${lb_ip}\"}"
  done
  local PATCH_BODY="{\"port\":{\"allowed_address_pairs\":[${PAIRS_JSON}]}}"

  local LB_TYPE
  LB_TYPE=$(grep -E '^\s*cluster_lb_type\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' "')
  LB_TYPE="${LB_TYPE:-kube_vip}"
  echo "patch_vip_allowed_pairs: [${LB_TYPE}] patching ALL node ports for cluster '${CLUSTER_NAME}' with VIP ${VIP} + LB IPs [${LB_IPS[*]}]"

  local SERVER_IDS=()
  if [[ -f "$TFSTATE" ]]; then
    while IFS= read -r sid; do
      [[ -n "$sid" ]] && SERVER_IDS+=("$sid")
    done < <(python3 -c "
import sys, json
with open('${TFSTATE}') as f:
    state = json.load(f)
cluster = '${CLUSTER_NAME}'
for res in state.get('resources', []):
    if res.get('type') != 'openstack_compute_instance_v2':
        continue
    for inst in res.get('instances', []):
        attrs = inst.get('attributes', {})
        name = attrs.get('name', '')
        if name.startswith(cluster + '-'):
            sid = attrs.get('id', '')
            if sid:
                print(sid)
" 2>/dev/null)
  fi

  local PORT_LIST
  if [[ ${#SERVER_IDS[@]} -gt 0 ]]; then
    local SERVER_IDS_STR
    SERVER_IDS_STR=$(IFS=,; echo "${SERVER_IDS[*]}")
    PORT_LIST=$(curl -sk -H "X-Auth-Token: $TOKEN" \
      "${NEUTRON_URL}/v2.0/ports" | \
      python3 -c "
import sys, json
server_ids = set('${SERVER_IDS_STR}'.split(','))
for p in json.load(sys.stdin).get('ports', []):
    if p.get('device_id','') in server_ids:
        print(p['id'], p['name'])
" 2>/dev/null)
  else
    echo "patch_vip_allowed_pairs: WARNING — no server IDs found in Terraform state; falling back to name-prefix port lookup."
    PORT_LIST=$(curl -sk -H "X-Auth-Token: $TOKEN" \
      "${NEUTRON_URL}/v2.0/ports" | \
      python3 -c "
import sys, json
prefix = '${CLUSTER_NAME}-'
for p in json.load(sys.stdin).get('ports', []):
    if p.get('name','').startswith(prefix):
        print(p['id'], p['name'])
" 2>/dev/null)
  fi

  if [[ -z "$PORT_LIST" ]]; then
    echo "patch_vip_allowed_pairs: no ports found to patch, skipping."
    return 0
  fi

  local PATCH_FAILED=0
  while IFS= read -r line; do
    local PORT_ID PORT_NAME RESULT
    PORT_ID=$(echo "$line" | awk '{print $1}')
    PORT_NAME=$(echo "$line" | awk '{print $2}')
    RESULT=$(curl -sk -X PUT \
      -H "X-Auth-Token: $TOKEN" \
      -H "Content-Type: application/json" \
      -d "$PATCH_BODY" \
      "${NEUTRON_URL}/v2.0/ports/${PORT_ID}" | \
      python3 -c "import sys,json; d=json.load(sys.stdin); p=d.get('port',{}); print('OK' if p.get('allowed_address_pairs') else str(d.get('NeutronError','unknown error')))" 2>/dev/null)
    echo "  port $PORT_NAME ($PORT_ID): $RESULT"
    [[ "$RESULT" != "OK" ]] && PATCH_FAILED=1
  done <<< "$PORT_LIST"

  if [[ "$PATCH_FAILED" -eq 1 ]]; then
    echo "patch_vip_allowed_pairs: ERROR — one or more ports failed to patch."
    echo "  Run manually: openstack --insecure port set --allowed-address ip-address=${VIP} <port-id>"
    return 1
  fi
  echo "patch_vip_allowed_pairs: all node ports patched successfully."
}

# =============================================================================
# Ansible helpers
# =============================================================================

ansible_prep() {
  gather_ans_creds
  # Skip pip install inside Docker — packages are already baked into the image.
  if [[ "${IAC_TOOLING:-}" != "docker" ]]; then
    if python3 -m pip install --user -q -r "$BASEDIR/requirements.txt"; then
      echo "ansible_prep: Python requirements installed from requirements.txt"
    else
      echo "ansible_prep: WARNING — could not install Python requirements. The 'kubernetes' library may be missing; storage tasks may fail."
    fi
  fi
  ansible-galaxy collection install -r "$BASEDIR/requirements.yml"
}

# =============================================================================
# Help
# =============================================================================

help() {
  echo ""
  echo "Usage: SYSTEM=<type> $0 <action> [<action> ...]"
  echo ""
  echo "  SYSTEM values   : openstack, bare_metal, vsphere (default: bare_metal)"
  echo ""
  echo "  Actions:"
  echo "    apply           - Provision cloud infrastructure (openstack / vsphere)"
  echo "    setup           - System and software baseline"
  echo "    install         - Install Kubernetes"
  echo "    update          - Update systems and/or Kubernetes"
  echo "    uninstall       - Uninstall Kubernetes"
  echo "    destroy         - Destroy cloud infrastructure (OpenStack only)"
  echo ""
  echo "  Valid groupings:"
  echo "    [apply setup install]   — full provision + install"
  echo "    [update]                — update only"
  echo "    [uninstall destroy]     — teardown"
  echo ""
  exit 1
}

# =============================================================================
# Argument parsing
# =============================================================================

if [[ "$#" -eq 0 ]]; then
  help
fi

arguments=()
for arg in $ARGS; do
  case "$arg" in
    apply)     arguments[0]=apply ;;
    setup)     arguments[1]=setup ;;
    install)   arguments[2]=install ;;
    update)    arguments[3]=update ;;
    uninstall) arguments[4]=uninstall ;;
    cleanup)   arguments[5]=cleanup ;;
    destroy)   arguments[6]=destroy ;;
    *)         echo "Unknown argument: $arg"; help ;;
  esac
done

creation_items=(apply setup install)
destruction_items=(uninstall cleanup destroy)

for item in "${arguments[@]}"; do
  [[ " ${creation_items[*]} " =~ " $item "    ]] && creation_flag=true
  [[ " ${destruction_items[*]} " =~ " $item " ]] && destruction_flag=true
  [[ "$item" == "update" ]]                       && update_flag=true
done

if [[ "$creation_flag" == "true" && ("$update_flag" == "true" || "$destruction_flag" == "true") ]] ||
   [[ "$update_flag" == "true" && ("$creation_flag" == "true" || "$destruction_flag" == "true") ]] ||
   [[ "$destruction_flag" == "true" && ("$creation_flag" == "true" || "$update_flag" == "true") ]]; then
  echo "ERROR: Invalid argument combination: $ARGS"
  echo ""
  help
fi

# Validate SYSTEM
if [[ "$SYSTEM" != "openstack" && "$SYSTEM" != "bare_metal" && "$SYSTEM" != "vsphere" ]]; then
  echo "ERROR: SYSTEM must be 'openstack', 'bare_metal', or 'vsphere' (got: $SYSTEM)"
  exit 1
fi

# Validate topology directory exists
if [[ ! -d "$TOPOLOGY_DIR" ]]; then
  echo "ERROR: Topology directory not found: $TOPOLOGY_DIR"
  exit 1
fi

# =============================================================================
# Main execution
# =============================================================================

for item in "${arguments[@]}"; do
  case "$item" in
    apply)
      echo "=== Provisioning infrastructure (SYSTEM=$SYSTEM) ==="
      if [[ "$SYSTEM" == "bare_metal" ]]; then
        echo "INFO: bare_metal has no cloud provisioning step (apply is a no-op)."
      else
        if [[ "$SYSTEM" == "openstack" ]]; then
          allocate_vip_floating_ip
        fi
        terraform_up
      fi
      # vsphere falls through to terraform_up (no floating IP allocation needed)
      ;;
    setup)
      echo "=== System baseline (SYSTEM=$SYSTEM) ==="
      ansible_prep
      ansible-playbook \
        -i "$ANSIBLE_INVENTORY" \
        --extra-vars "deployment_type=$SYSTEM" \
        --extra-vars "$ANSIBLE_VARS" \
        "$TOPOLOGY_DIR/playbooks/systems-install.yaml" \
        --flush-cache --tags install
      ;;
    install)
      echo "=== Installing Kubernetes ==="
      # On OpenStack, patch Neutron port allowed_address_pairs before kubeadm runs.
      # Required even for install-only re-runs; patch_vip_allowed_pairs is idempotent.
      if [[ "$SYSTEM" == "openstack" ]]; then
        patch_vip_allowed_pairs || { echo "ERROR: patch_vip_allowed_pairs failed — aborting to prevent kubeadm join timeout."; exit 1; }
      fi
      ansible_prep
      ansible-playbook \
        -i "$ANSIBLE_INVENTORY" \
        --extra-vars "deployment_type=$SYSTEM" \
        --extra-vars "iac_tooling=$IAC_TOOLING" \
        --extra-vars "iac_inventory_dir=$WORKDIR" \
        --extra-vars "k8s_tool_base=$K8S_TOOL_BASE" \
        --extra-vars "$ANSIBLE_VARS" \
        "$TOPOLOGY_DIR/playbooks/kubernetes-install.yaml" \
        --flush-cache --tags install
      ;;
    update)
      echo "TODO: update not yet implemented"
      ;;
    uninstall)
      echo "=== Uninstalling Kubernetes ==="
      ansible_prep
      ansible-playbook \
        -i "$ANSIBLE_INVENTORY" \
        --extra-vars "deployment_type=$SYSTEM" \
        --extra-vars "iac_tooling=$IAC_TOOLING" \
        --extra-vars "iac_inventory_dir=$WORKDIR" \
        --extra-vars "k8s_tool_base=$K8S_TOOL_BASE" \
        --extra-vars "$ANSIBLE_VARS" \
        "$TOPOLOGY_DIR/playbooks/kubernetes-uninstall.yaml" \
        --flush-cache --tags uninstall
      rm -rf "$WORKDIR"/*-oss-kubeconfig.conf 2>/dev/null
      rm -rf "$WORKDIR"/sas-iac-buildinfo-cm.yaml 2>/dev/null
      ;;
    cleanup)
      echo "TODO: cleanup not yet implemented"
      ;;
    destroy)
      echo "=== Destroying infrastructure (SYSTEM=$SYSTEM) ==="
      if [[ "$SYSTEM" == "bare_metal" ]]; then
        echo "INFO: bare_metal has no cloud infrastructure to destroy."
        exit 0
      fi
      # vsphere and openstack both proceed to terraform_down
      if [[ -f "$TFSTATE" ]]; then
        if [[ "$IAC_TOOLING" != "docker" ]]; then
          read -rp 'Are you absolutely sure? [yes/no]: ' CONFIRMATION
          if [[ "$CONFIRMATION" != "yes" && "$CONFIRMATION" != "y" ]]; then
            echo "Destroy cancelled."
            exit 1
          fi
        fi
        terraform_down
        clean_up
        rm -rf "$TFSTATE" "$TFSTATE.backup" 2>/dev/null
        rm -rf "$BASEDIR"/ssl-cert-sas-*-pgsql.{key,pem} 2>/dev/null
      else
        echo "No Terraform state found — nothing to destroy."
        exit 0
      fi
      ;;
  esac
done

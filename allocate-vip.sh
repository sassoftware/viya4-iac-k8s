#!/usr/bin/env bash
# allocate-vip.sh - Allocate OpenStack floating IPs for the cluster:
#   1. cluster_vip_ip      — kube-vip control-plane HA VIP
#   2. cluster_lb_addresses — one or more kube-vip LoadBalancer service IPs
#
# Both are written into terraform.tfvars automatically.
#
# Usage:
#   source ~/.openstack_creds.env
#   ./allocate-vip.sh
#
# To allocate extra LoadBalancer IPs (e.g. for V4_CFG_CAS_ENABLE_LOADBALANCER,
# consul LB, connect LB, etc.), set LB_IP_COUNT before running:
#   LB_IP_COUNT=3 ./allocate-vip.sh
#
# After running:
#   1. Register IPs in your DNS zone (see NEXT STEPS printed by the script)
#   2. Update cluster_vip_fqdn in terraform.tfvars
#   3. Run: export SYSTEM=openstack && ./oss-k8s.sh apply setup install

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS="${SCRIPT_DIR}/terraform.tfvars"

# ---------------------------------------------------------------------------
# Validate environment
# ---------------------------------------------------------------------------
# If creds were sourced via 'source ~/.openstack_creds.env' in ksh the
# variables may not be exported.  Re-export here to be safe.
if [[ -f "$HOME/.openstack_creds.env" ]] && [[ -z "$OS_AUTH_URL" ]]; then
    export $(grep -v '^#' "$HOME/.openstack_creds.env" | grep -v '^[[:space:]]*$' | xargs)
fi

if [[ -z "$OS_AUTH_URL" ]]; then
    echo "ERROR: OpenStack credentials not sourced. Run:"
    echo "  export \$(grep -v '^#' ~/.openstack_creds.env | xargs)"
    exit 1
fi

# HPOS OpenStack uses a self-signed / internal CA — disable SSL verification.
# Also set OS_PROJECT_DOMAIN_NAME which is required by Keystone v3 but not
# always included in .openstack_creds.env.
export OS_INSECURE=true
export PYTHONHTTPSVERIFY=0
: "${OS_PROJECT_DOMAIN_NAME:=${OS_USER_DOMAIN_NAME:-Default}}"
export OS_PROJECT_DOMAIN_NAME

# ---------------------------------------------------------------------------
# Read network name from tfvars
# ---------------------------------------------------------------------------
NETWORK=$(grep -E '^\s*openstack_network_name\s*=' "$TFVARS" 2>/dev/null \
    | head -1 | sed 's/.*=\s*//' | tr -d ' "')

if [[ -z "$NETWORK" ]]; then
    echo "ERROR: openstack_network_name not set in $TFVARS"
    exit 1
fi

# ---------------------------------------------------------------------------
# Helper: allocate one floating IP from OpenStack
# ---------------------------------------------------------------------------
allocate_fip() {
    local label="$1"
    local FIP_JSON FIP_IP
    echo "Allocating floating IP for ${label} from network '${NETWORK}'..." >&2
    FIP_JSON=$(openstack --insecure floating ip create "$NETWORK" -f json 2>&1) || true
    FIP_IP=$(echo "$FIP_JSON" | python3 -c \
        "import sys,json; print(json.load(sys.stdin).get('floating_ip_address',''))" 2>/dev/null) || true
    if [[ -z "$FIP_IP" ]]; then
        echo "ERROR: Failed to allocate floating IP for ${label} from network '${NETWORK}'." >&2
        echo "Check your OpenStack credentials and network name." >&2
        exit 1
    fi
    echo "$FIP_IP"
}

# ---------------------------------------------------------------------------
# Check cluster_vip_ip — skip allocation if already set
# ---------------------------------------------------------------------------
CURRENT_VIP=$(grep -E '^\s*cluster_vip_ip\s*=' "$TFVARS" 2>/dev/null \
    | head -1 | sed 's/.*=\s*//' | tr -d ' "')

if [[ -n "$CURRENT_VIP" && "$CURRENT_VIP" != "null" ]]; then
    echo "[cluster_vip_ip]     already set to: $CURRENT_VIP  (skipping allocation)"
    VIP="$CURRENT_VIP"
    VIP_SKIPPED=true
else
    VIP=$(allocate_fip "cluster_vip_ip (control-plane HA VIP)")
    VIP_SKIPPED=false
fi

# Number of LoadBalancer IPs to allocate. Default 1 (sufficient for ingress-only
# Viya deployments). Increase when enabling features that create additional
# LoadBalancer-type services, for example:
#   V4_CFG_CAS_ENABLE_LOADBALANCER: true  (+1 IP)
#   consul or connect LoadBalancers       (+1 IP each)
# Example: LB_IP_COUNT=3 ./allocate-vip.sh
LB_IP_COUNT="${LB_IP_COUNT:-1}"

# ---------------------------------------------------------------------------
# Check cluster_lb_addresses — skip allocation if already set to a real IP
# ---------------------------------------------------------------------------
CURRENT_LB=$(grep -E '^\s*cluster_lb_addresses\s*=' "$TFVARS" 2>/dev/null \
    | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ -n "$CURRENT_LB" ]]; then
    echo "[cluster_lb_addresses] already contains IPs (first: $CURRENT_LB)  (skipping allocation)"
    LB_VIP="$CURRENT_LB"
    LB_SKIPPED=true
else
    LB_VIPS=()
    for i in $(seq 1 "$LB_IP_COUNT"); do
        _IP=$(allocate_fip "cluster_lb_addresses[${i}] (LoadBalancer VIP)")
        LB_VIPS+=("$_IP")
    done
    LB_VIP="${LB_VIPS[0]}"   # primary (first) LB IP
    LB_SKIPPED=false
fi

# ---------------------------------------------------------------------------
# Write cluster_vip_ip into terraform.tfvars (if newly allocated)
# ---------------------------------------------------------------------------
if [[ "$VIP_SKIPPED" == "false" ]]; then
    VIP_LINE="cluster_vip_ip      = \"${VIP}\""
    if grep -qE '^\s*#?\s*cluster_vip_ip\s*=' "$TFVARS"; then
        python3 -c "
import re, sys
line = sys.argv[1]
content = open(sys.argv[2]).read()
content = re.sub(r'^\s*#?\s*cluster_vip_ip\s*=.*', line, content, flags=re.MULTILINE)
open(sys.argv[2], 'w').write(content)
" "$VIP_LINE" "$TFVARS"
    else
        python3 -c "
import re, sys
line = sys.argv[1]
content = open(sys.argv[2]).read()
content = re.sub(r'([ \t]*cluster_vip_version[^\n]*)', r'\1\n' + line, content, flags=re.MULTILINE)
open(sys.argv[2], 'w').write(content)
" "$VIP_LINE" "$TFVARS"
    fi
fi

# ---------------------------------------------------------------------------
# Write cluster_lb_addresses into terraform.tfvars (if newly allocated)
# ---------------------------------------------------------------------------
if [[ "$LB_SKIPPED" == "false" ]]; then
    # Build a single-line array: ["range-global: IP1-IP1", "range-global: IP2-IP2", ...]
    # Each floating IP is represented as a single-IP range because OpenStack floating
    # IPs are not guaranteed to be consecutive.
    LB_ENTRIES=""
    for _ip in "${LB_VIPS[@]}"; do
        [[ -n "$LB_ENTRIES" ]] && LB_ENTRIES+=", "
        LB_ENTRIES+="\"range-global: ${_ip}-${_ip}\""
    done
    LB_LINE="cluster_lb_addresses = [${LB_ENTRIES}]"

    if grep -qE '^\s*cluster_lb_addresses\s*=' "$TFVARS"; then
        python3 -c "
import re, sys
line = sys.argv[1]
content = open(sys.argv[2]).read()
content = re.sub(r'^\s*cluster_lb_addresses\s*=.*', line, content, flags=re.MULTILINE)
open(sys.argv[2], 'w').write(content)
" "$LB_LINE" "$TFVARS"
    else
        python3 -c "
import re, sys
line = sys.argv[1]
content = open(sys.argv[2]).read()
content = re.sub(r'([ \t]*cluster_lb_type[^\n]*)', r'\1\n' + line, content, flags=re.MULTILINE)
open(sys.argv[2], 'w').write(content)
" "$LB_LINE" "$TFVARS"
    fi
fi

# ---------------------------------------------------------------------------
# Derive prefix from tfvars for concrete DNS examples
# ---------------------------------------------------------------------------
PREFIX=$(grep -E '^\s*prefix\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' "')
DNS_ZONE=$(grep -E '^\s*cluster_domain\s*=' "$TFVARS" 2>/dev/null | head -1 | sed 's/.*=\s*"\(.*\)".*/\1/' | tr -d ' "')
[[ -z "$PREFIX" ]]   && PREFIX="<prefix>"
[[ -z "$DNS_ZONE" ]] && DNS_ZONE="<your-dns-zone>"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  IPs allocated and written to terraform.tfvars:"
echo ""
echo "  [1] cluster_vip_ip      = \"$VIP\""
echo "        Purpose : kube-vip control-plane HA endpoint"
echo "        This IP is used by kubeadm as the API server VIP."
echo "        kube-vip binds this IP on the primary control-plane"
echo "        node and fails it over on node failure."
echo ""
if [[ "$LB_SKIPPED" == "false" ]]; then
    echo "  [2] cluster_lb_addresses = [ ${LB_ENTRIES} ]"
else
    echo "  [2] cluster_lb_addresses = (already set — $LB_VIP ...)"
fi
echo "        Purpose : kube-vip cloud-provider LoadBalancer service IPs"
echo "        These IPs are assigned to Kubernetes LoadBalancer-type services"
echo "        (ingress-nginx, CAS external LB, consul LB, connect LB, etc.)."
echo ""
echo "  NEXT STEPS:"
echo ""
echo "  1. Register IPs in your DNS zone (cluster_domain = ${DNS_ZONE}):"
echo ""
echo "     a) Control-plane VIP — used as the Kubernetes API server endpoint:"
echo "          A    ${PREFIX}-vip.${DNS_ZONE}     ->  $VIP"
echo "          PTR  $VIP  ->  ${PREFIX}-vip.${DNS_ZONE}"
echo "          Then set in terraform.tfvars:"
echo "            cluster_vip_fqdn = \"${PREFIX}-vip.${DNS_ZONE}\""
echo ""
echo "     b) LoadBalancer wildcard — resolves ALL SAS Viya app hostnames:"
echo "          A (or ALIAS/CNAME)  *.${PREFIX}.${DNS_ZONE}  ->  $LB_VIP"
echo ""
echo "        SAS Viya apps are served via ingress using the pattern:"
echo "          <app>.${PREFIX}.${DNS_ZONE}"
echo "        A wildcard record routes all of them to the LB IP without"
echo "        needing a separate A record per app."
echo ""
if [[ "$LB_SKIPPED" == "false" && ${#LB_VIPS[@]} -gt 1 ]]; then
    echo "        Additional LB IPs (for CAS / consul / connect LBs, etc.):"
    for _idx in "${!LB_VIPS[@]}"; do
        [[ $_idx -eq 0 ]] && continue   # already shown above
        echo "          A  <service-hostname>.${DNS_ZONE}  ->  ${LB_VIPS[$_idx]}"
    done
    echo "        Register these once the LoadBalancer services are created"
    echo "        and their hostnames are known (set in DAC ansible-vars.yaml)."
    echo ""
fi
echo "  2. Verify DNS is live before proceeding:"
echo "       nslookup ${PREFIX}-vip.${DNS_ZONE}"
echo "       nslookup test.${PREFIX}.${DNS_ZONE}   # should resolve to $LB_VIP"
echo ""
echo "  3. Then run:"
echo "       export SYSTEM=openstack"
echo "       ./oss-k8s.sh apply setup install"
echo ""
echo "  NOTE: If you plan to use V4_CFG_CAS_ENABLE_LOADBALANCER, consul LB,"
echo "        or connect LB in viya4-deployment (DAC), you need one additional"
echo "        floating IP per such feature. Re-run with e.g.:"
echo "          LB_IP_COUNT=3 ./allocate-vip.sh"
echo "        (skip if cluster_lb_addresses already contains enough IPs)"
echo "============================================================"
echo ""

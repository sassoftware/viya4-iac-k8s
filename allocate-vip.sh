#!/usr/bin/env bash
# allocate-vip.sh - Allocate two OpenStack floating IPs:
#   1. cluster_vip_ip      — kube-vip control-plane HA VIP
#   2. cluster_lb_addresses — kube-vip cloud-provider LoadBalancer service VIP
#
# Both IPs are written into terraform.tfvars automatically.
#
# Usage:
#   source ~/.openstack_creds.env
#   ./allocate-vip.sh
#
# After running:
#   1. Register both IPs in names.sas.com (unx.sas.com domain)
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

# ---------------------------------------------------------------------------
# Check cluster_lb_addresses — skip allocation if already set to a real IP
# ---------------------------------------------------------------------------
CURRENT_LB=$(grep -E '^\s*cluster_lb_addresses\s*=' "$TFVARS" 2>/dev/null \
    | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ -n "$CURRENT_LB" ]]; then
    echo "[cluster_lb_addresses] already set to: $CURRENT_LB  (skipping allocation)"
    LB_VIP="$CURRENT_LB"
    LB_SKIPPED=true
else
    LB_VIP=$(allocate_fip "cluster_lb_addresses (LoadBalancer service VIP)")
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
    LB_LINE="cluster_lb_addresses = [\"range-global: ${LB_VIP}-${LB_VIP}\"]"
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
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Two VIPs allocated and written to terraform.tfvars:"
echo ""
echo "  [1] cluster_vip_ip      = \"$VIP\""
echo "        Purpose : kube-vip control-plane HA endpoint"
echo "        This IP is used by kubeadm as the API server VIP."
echo "        kube-vip binds this IP on the primary control-plane"
echo "        node and fails it over on node failure."
echo ""
echo "  [2] cluster_lb_addresses = \"range-global: ${LB_VIP}-${LB_VIP}\""
echo "        Purpose : kube-vip cloud-provider LoadBalancer service VIP"
echo "        This IP is assigned to Kubernetes LoadBalancer-type"
echo "        services (e.g. the Viya SAS/HTTP ingress controller)."
echo ""
echo "  NEXT STEPS:"
echo ""
echo "  1. Register both IPs in names.sas.com (unx.sas.com domain):"
echo "       A    <prefix>-vip.unx.sas.com        ->  $VIP"
echo "       PTR  $VIP                             ->  <prefix>-vip.unx.sas.com"
echo "       A    <prefix>-lb.unx.sas.com         ->  $LB_VIP"
echo "       PTR  $LB_VIP                         ->  <prefix>-lb.unx.sas.com"
echo ""
echo "  2. Update cluster_vip_fqdn in terraform.tfvars:"
echo "       cluster_vip_fqdn = \"<prefix>-vip.unx.sas.com\""
echo ""
echo "  3. Verify DNS is live:"
echo "       nslookup <prefix>-vip.unx.sas.com"
echo "       nslookup <prefix>-lb.unx.sas.com"
echo ""
echo "  4. Then run:"
echo "       export SYSTEM=openstack"
echo "       ./oss-k8s.sh apply setup install"
echo "============================================================"
echo ""

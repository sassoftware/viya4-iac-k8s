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
#   1. Register both IPs in your DNS zone (e.g. your-domain.example.com)
#   2. Update cluster_vip_fqdn in terraform.tfvars
#   3. Run: export SYSTEM=openstack && ./oss-k8s.sh apply setup install

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS="${SCRIPT_DIR}/terraform.tfvars"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
# Number of floating IPs to allocate for the LoadBalancer address pool.
#
# Each Kubernetes LoadBalancer-type Service consumes one IP from this pool.
# When deploying SAS Viya with viya4-deployment the following options each
# require an additional IP:
#
#   - 1 IP  (always required)                        Envoy (Contour) — main Viya HTTPS endpoint
#   - 1 IP  (V4_CFG_CAS_ENABLE_LOADBALANCER: true)   CAS binary-port LoadBalancer
#   - 1 IP  (CAS Connect LoadBalancer, if enabled)
#   - 1 IP  (Consul LoadBalancer, if enabled)
#
# If the pool runs out of IPs a LoadBalancer Service will remain in Pending
# state and related pods (e.g. CAS) will fail to start.
# The default of 5 provides headroom for a full Viya + CAS LB deployment.
# Override before running the script:  LB_COUNT=8 ./allocate-vip.sh
#
: "${LB_COUNT:=5}"

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
# Helper: build the cluster_lb_addresses HCL value from a list of sorted IPs
# ---------------------------------------------------------------------------
# - Contiguous block within the same /24 subnet → "range-global: first-last"
# - Otherwise (non-contiguous or cross-/24)     → "cidr-global: IP1/32,IP2/32,..."
# Both formats are valid kube-vip cloud-provider ConfigMap entries.
build_lb_addresses_value() {
    local -a ips=("$@")
    local n=${#ips[@]}
    local contiguous=true
    local prev_a prev_b prev_c prev_d this_a this_b this_c this_d

    IFS='.' read -r prev_a prev_b prev_c prev_d <<< "${ips[0]}"
    for (( i=1; i<n; i++ )); do
        IFS='.' read -r this_a this_b this_c this_d <<< "${ips[$i]}"
        if [[ "$this_a" != "$prev_a" || "$this_b" != "$prev_b" || "$this_c" != "$prev_c" \
              || $this_d -ne $((prev_d + 1)) ]]; then
            contiguous=false
            break
        fi
        prev_d=$this_d
    done

    if [[ "$contiguous" == "true" ]]; then
        echo "[\"range-global: ${ips[0]}-${ips[$((n-1))]}\"]" 
    else
        local cidr_list
        cidr_list=$(printf '%s/32,' "${ips[@]}" | sed 's/,$//')
        echo "[\"cidr-global: ${cidr_list}\"]"
    fi
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
# Check cluster_lb_addresses — skip allocation if already contains any IP
# ---------------------------------------------------------------------------
CURRENT_LB=$(grep -E '^\s*cluster_lb_addresses\s*=' "$TFVARS" 2>/dev/null \
    | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)

if [[ -n "$CURRENT_LB" ]]; then
    echo "[cluster_lb_addresses] already contains IPs (skipping allocation)"
    LB_SKIPPED=true
else
    LB_IPS=()
    echo "Allocating ${LB_COUNT} floating IP(s) for the LoadBalancer pool..."
    for i in $(seq 1 "$LB_COUNT"); do
        ip=$(allocate_fip "cluster_lb_addresses pool IP ${i}/${LB_COUNT}")
        LB_IPS+=("$ip")
    done
    # Sort IPs numerically so contiguous detection works correctly
    IFS=$'\n' SORTED_LB_IPS=($(printf '%s\n' "${LB_IPS[@]}" | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n))
    unset IFS
    LB_ADDRESSES_VALUE=$(build_lb_addresses_value "${SORTED_LB_IPS[@]}")
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
    LB_LINE="cluster_lb_addresses = ${LB_ADDRESSES_VALUE}"
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

# Determine display values for the summary
if [[ "$LB_SKIPPED" == "false" ]]; then
    LB_FIRST_IP="${SORTED_LB_IPS[0]}"
    LB_DISPLAY="${LB_ADDRESSES_VALUE}"
else
    LB_FIRST_IP="$CURRENT_LB"
    LB_DISPLAY="(already set — see terraform.tfvars)"
fi

echo ""
echo "============================================================"
echo "  VIPs allocated/verified for terraform.tfvars:"
echo ""
echo "  [1] cluster_vip_ip      = \"$VIP\""
echo "        Purpose : kube-vip control-plane HA endpoint"
echo "        kube-vip binds this IP on the primary control-plane"
echo "        node and fails it over on node failure."
echo ""
echo "  [2] cluster_lb_addresses = ${LB_DISPLAY}"
echo "        Purpose : kube-vip cloud-provider LoadBalancer IP pool"
if [[ "$LB_SKIPPED" == "false" ]]; then
    echo "        ${#SORTED_LB_IPS[@]} IP(s) allocated for LoadBalancer-type Services:"
    for _ip in "${SORTED_LB_IPS[@]}"; do
        echo "          $_ip"
    done
fi
echo ""
echo "  IMPORTANT — LoadBalancer IP pool size:"
echo "    Each Kubernetes LoadBalancer-type Service consumes one IP."
echo "    viya4-deployment options that each require an additional IP:"
echo "      - 1 IP always: Envoy (Contour) — main Viya HTTPS endpoint"
echo "      - V4_CFG_CAS_ENABLE_LOADBALANCER: true  (CAS binary-port LB)"
echo "      - CAS Connect LoadBalancer (if enabled)"
echo "      - Consul LoadBalancer (if enabled)"
echo "    If the pool runs out of IPs those Services remain Pending and"
echo "    related pods (e.g. CAS) will fail to start."
echo "    Increase LB_COUNT and re-run if needed:  LB_COUNT=8 ./allocate-vip.sh"
echo ""
echo "  NEXT STEPS:"
echo ""
echo "  1. Register IPs in your DNS zone (value of cluster_domain in terraform.tfvars):"
echo "       A    <prefix>-vip.<your-dns-zone>   ->  $VIP"
echo "       PTR  $VIP                          ->  <prefix>-vip.<your-dns-zone>"
echo "       A    <prefix>-lb.<your-dns-zone>    ->  ${LB_FIRST_IP}  (ingress-nginx)"
echo "       PTR  ${LB_FIRST_IP}                ->  <prefix>-lb.<your-dns-zone>"
if [[ "$LB_SKIPPED" == "false" && ${#SORTED_LB_IPS[@]} -gt 1 ]]; then
    echo ""
    echo "       Additional LB pool IPs (for CAS LB and similar services):"
    for _ip in "${SORTED_LB_IPS[@]:1}"; do
        echo "         $_ip — register if enabling V4_CFG_CAS_ENABLE_LOADBALANCER or similar"
    done
fi
echo ""
echo "  2. Update cluster_vip_fqdn in terraform.tfvars:"
echo "       cluster_vip_fqdn = \"<prefix>-vip.<your-dns-zone>\""
echo ""
echo "  3. Verify DNS is live:"
echo "       nslookup <prefix>-vip.<your-dns-zone>"
echo "       nslookup <prefix>-lb.<your-dns-zone>"
echo ""
echo "  4. Then run:"
echo "       export SYSTEM=openstack"
echo "       ./oss-k8s.sh apply setup install"
echo "============================================================"
echo ""

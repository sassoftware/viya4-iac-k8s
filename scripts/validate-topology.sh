#!/usr/bin/env bash
# validate-topology.sh — Verify that a topology directory is correctly structured
# and registered in the root dispatcher.
#
# Usage:
#   scripts/validate-topology.sh                   # validate all topologies
#   scripts/validate-topology.sh azure openstack   # validate specific topologies
#
# Exit codes:
#   0 — all checks passed (warnings are non-fatal)
#   1 — one or more ERROR checks failed

set -euo pipefail

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPOLOGIES_DIR="$BASEDIR/topologies"

# Files/dirs that EVERY topology must contain.
REQUIRED_FILES=(
  "main.tf"
  "variables.tf"
  "outputs.tf"
  "versions.tf"
  "locals.tf"
  "provider.tf.example"
  "ansible.cfg"
  "requirements.txt"
  "requirements.yml"
  "playbooks/systems-install.yaml"
  "playbooks/kubernetes-install.yaml"
  "playbooks/kubernetes-uninstall.yaml"
  "roles/systems"
  "templates/ansible-vars.yaml.tmpl"
  "templates/inventory.tmpl"
)

# Counters
pass=0; fail=0; warn=0

_ok()    { echo "  [OK]    $*"; ((pass++)) || true; }
_err()   { echo "  [ERROR] $*"; ((fail++)) || true; }
_warn()  { echo "  [WARN]  $*"; ((warn++)) || true; }

validate_topology() {
  local NAME="$1"
  local DIR="$TOPOLOGIES_DIR/$NAME"

  echo ""
  echo "=== Topology: $NAME ==="

  # ── Directory existence ──────────────────────────────────────────────────
  if [[ ! -d "$DIR" ]]; then
    _err "Directory not found: $DIR"
    return
  fi

  # ── Required files ───────────────────────────────────────────────────────
  for f in "${REQUIRED_FILES[@]}"; do
    if [[ -e "$DIR/$f" ]]; then
      _ok "$f"
    else
      _err "Missing required file/dir: $f"
    fi
  done

  # ── ansible.cfg: dual roles_path ────────────────────────────────────────
  if grep -q "../../roles" "$DIR/ansible.cfg" 2>/dev/null; then
    _ok "ansible.cfg has dual roles_path (./roles:../../roles)"
  else
    _warn "ansible.cfg does not reference shared ../../roles — run the roles consolidation step"
  fi

  # ── versions.tf: required_version present ────────────────────────────────
  if grep -q "required_version" "$DIR/versions.tf" 2>/dev/null; then
    _ok "versions.tf has required_version constraint"
  else
    _err "versions.tf is missing required_version"
  fi

  # ── provider.tf not committed (credentials leak risk) ────────────────────
  if [[ -f "$DIR/provider.tf" ]]; then
    _warn "provider.tf exists on disk — confirm it is in .gitignore; never commit credentials"
  fi

  # ── Sample tfvars present ────────────────────────────────────────────────
  if ls "$DIR"/sample-input-*.tfvars &>/dev/null; then
    _ok "sample-input-*.tfvars found"
  else
    _warn "No sample-input-*.tfvars — operators need a reference file"
  fi

  # ── Root dispatcher registration: locals.tf ──────────────────────────────
  if grep -q "is_${NAME}" "$BASEDIR/locals.tf" 2>/dev/null; then
    _ok "Registered in root locals.tf  (is_${NAME})"
  else
    _err "NOT in root locals.tf  — add: is_${NAME} = local.deployment_type_normalized == \"${NAME}\""
  fi

  # ── Root dispatcher registration: main.tf ────────────────────────────────
  if grep -q "\"./topologies/${NAME}\"" "$BASEDIR/main.tf" 2>/dev/null; then
    _ok "Registered in root main.tf  (module source)"
  else
    _err "NOT in root main.tf  — add a module block with source = \"./topologies/${NAME}\""
  fi

  # ── Root dispatcher registration: outputs.tf ─────────────────────────────
  # After the active_module refactor outputs.tf no longer lists topology names,
  # so we check that active_module is present in locals.tf instead.
  if grep -q "active_module" "$BASEDIR/locals.tf" 2>/dev/null; then
    if grep -q "$NAME" "$BASEDIR/locals.tf" 2>/dev/null; then
      _ok "active_module in locals.tf covers this topology"
    else
      _err "active_module in locals.tf does NOT include ${NAME} — extend the conditional"
    fi
  else
    # Legacy ternary-chain style: check outputs.tf directly
    if grep -q "module\.${NAME}" "$BASEDIR/outputs.tf" 2>/dev/null; then
      _ok "outputs.tf references module.${NAME}"
    else
      _err "outputs.tf does not forward ${NAME} outputs — extend all output ternaries"
    fi
  fi

  # ── deployment_type validation list updated ───────────────────────────────
  if grep -q "\"${NAME}\"" "$BASEDIR/variables.tf" 2>/dev/null; then
    _ok "variables.tf deployment_type validation includes \"${NAME}\""
  else
    _err "variables.tf deployment_type validation missing \"${NAME}\" — add to allowed values"
  fi
}

# ── Build the list of topologies to validate ─────────────────────────────────
if [[ "$#" -ge 1 ]]; then
  TOPOLOGIES=("$@")
else
  TOPOLOGIES=()
  while IFS= read -r d; do
    TOPOLOGIES+=("$(basename "$d")")
  done < <(find "$TOPOLOGIES_DIR" -maxdepth 1 -mindepth 1 -type d | sort)
fi

for topo in "${TOPOLOGIES[@]}"; do
  validate_topology "$topo"
done

echo ""
echo "================================================="
printf "  Summary: %d passed,  %d warnings,  %d errors\n" "$pass" "$warn" "$fail"
echo "================================================="

if [[ "$fail" -gt 0 ]]; then
  echo "Fix all [ERROR] items before adding this topology to production."
  exit 1
fi
exit 0

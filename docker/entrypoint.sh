#!/usr/bin/env bash

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

set -e

# Set up container user
echo "viya4-iac-k8s:x:$(id -u):$(id -g)::/viya4-iac-k8s:/bin/bash" >> /etc/passwd
echo "viya4-iac-k8s:x:$(id -G | cut -d' ' -f 2):" >> /etc/group

# Route to the correct script based on SYSTEM env var.
#   SYSTEM=azure                → scripts/deploy.sh
#   SYSTEM=openstack|bare_metal|vsphere → scripts/oss-k8s.sh
SYSTEM="${SYSTEM:-azure}"

# Guard: /workspace must be a non-empty mounted volume, not an anonymous Docker volume.
# If the directory appears empty (no .keep file and no files), the user likely forgot -v.
if [[ ! -e "/workspace/.keep" ]] && [[ -z "$(ls -A /workspace 2>/dev/null)" ]]; then
  echo "ERROR: /workspace appears unmounted or empty."
  echo "  Run with: docker run -v /path/to/your/workspace:/workspace ..."
  echo "  Hint: The workspace must contain your terraform.tfvars (and terraform.tfstate if resuming)."
  exit 1
fi

# Set ANSIBLE_CONFIG to the active topology's ansible.cfg
export ANSIBLE_CONFIG="/viya4-iac-k8s/topologies/${SYSTEM}/ansible.cfg"

if [[ "$SYSTEM" == "azure" ]]; then
  exec /viya4-iac-k8s/scripts/deploy.sh "$@"
else
  exec /viya4-iac-k8s/scripts/oss-k8s.sh "$@"
fi

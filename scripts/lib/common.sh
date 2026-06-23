#!/usr/bin/env bash

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Shared utility functions sourced by deploy.sh and oss-k8s.sh.
# Source this file after WORKDIR and TOPOLOGY_DIR are set.

# gather_ans_creds — resolve Ansible SSH credentials, prompting only when needed.
# Resolution order for ANSIBLE_USER/PASSWORD:
#   1. Already-exported env vars (ANSIBLE_USER, ANSIBLE_PASSWORD)
#   2. TF_VAR_ansible_user/password (set by Docker --env-file or OpenStack creds file)
#   3. Values sourced from ~/.openstack_creds.env (if TF_VAR_ansible_user not yet set)
#   4. Interactive prompt (last resort)
gather_ans_creds() {
  # Source the creds file so TF_VAR_ansible_user/TF_VAR_ansible_password are available
  # (OpenStack RC files often include TF_VAR_* vars for this tool).
  if [[ -f "$HOME/.openstack_creds.env" ]] && [[ -z "$TF_VAR_ansible_user" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$HOME/.openstack_creds.env"
    set +a
  fi

  ANSIBLE_USER="${ANSIBLE_USER:-$TF_VAR_ansible_user}"
  ANSIBLE_PASSWORD="${ANSIBLE_PASSWORD:-$TF_VAR_ansible_password}"

  if [[ -z "$ANSIBLE_USER" ]]; then
    read -rp 'ansible_user: ' ANSIBLE_USER
  fi
  # Only prompt for ansible_password if it was never set at all — an explicitly
  # empty value means SSH key auth is being used; do not prompt in that case.
  if [[ -z "$ANSIBLE_PASSWORD" && -z "$TF_VAR_ansible_password" ]]; then
    read -rsp 'ansible_password: ' ANSIBLE_PASSWORD
    echo
  fi
}

# clean_up — remove kubeconfig and build-info artifacts from the workspace.
clean_up() {
  rm -rf "$WORKDIR"/*-oss-kubeconfig.conf 2>/dev/null || true
  rm -rf "$WORKDIR"/sas-iac-buildinfo-cm.yaml 2>/dev/null || true
}

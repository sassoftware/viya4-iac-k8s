# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Bare Metal Topology — Sample Input Variables
# =============================================================================
# Customize this file with your actual node IPs and cluster settings.
# No cloud credentials are required — Terraform only writes the inventory
# and ansible-vars.yaml files from the IPs you provide below.
#
# Usage (from repo root — recommended):
#   terraform init
#   terraform plan  -var-file="topologies/bare_metal/sample-input-bare-metal.tfvars"
#   terraform apply -var-file="topologies/bare_metal/sample-input-bare-metal.tfvars"
#
# Usage (topology standalone):
#   cd topologies/bare_metal
#   terraform init
#   terraform plan  -var-file="sample-input-bare-metal.tfvars"
#   terraform apply -var-file="sample-input-bare-metal.tfvars"
#
# With oss-k8s.sh (skips Terraform entirely — reads inventory + ansible-vars from disk):
#   SYSTEM=bare_metal ./scripts/oss-k8s.sh setup install
# =============================================================================

# ****************  REQUIRED VARIABLES  ****************

# Deployment type — selects bare_metal topology at root dispatcher level
deployment_type = "bare_metal"

# Cluster prefix — used in naming (e.g. "myteam-oss-*")
prefix = "FIXME"

# Ansible SSH credentials
ansible_user     = "FIXME"
ansible_password = "FIXME"

# OS type on bare metal nodes — "ubuntu" (22.04/24.04) or "rocky" (Rocky Linux 9)
vm_os = "ubuntu"

# Control plane HA VIP — an unused IP reachable by all nodes
cluster_vip_ip   = "FIXME"
cluster_vip_fqdn = "FIXME" # e.g. "mycluster-vip.example.com"
cluster_domain   = "FIXME" # e.g. "example.com"

# ****************  NODE POOLS  ****************
# All IPs must be pre-assigned on the physical/virtual machines.
# At minimum you need: control_plane, system, and one worker pool.

node_pools = {
  control_plane = {
    ip_addresses = [
      "FIXME-CP-1", # e.g. "192.168.1.10"
      "FIXME-CP-2",
      "FIXME-CP-3",
    ]
    node_taints = []
    node_labels = {}
  }
  system = {
    ip_addresses = [
      "FIXME-SYS-1",
    ]
    node_taints = ["kubernetes.azure.com/scalesetpriority=spot:NoSchedule"]
    node_labels = { "kubernetes.azure.com/mode" = "system" }
  }
  cas = {
    ip_addresses = [
      "FIXME-CAS-1",
      "FIXME-CAS-2",
    ]
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = { "workload.sas.com/class" = "cas" }
  }
  compute = {
    ip_addresses = [
      "FIXME-COMPUTE-1",
    ]
    node_taints = ["workload.sas.com/class=compute:NoSchedule"]
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  }
  stateless = {
    ip_addresses = [
      "FIXME-STATELESS-1",
    ]
    node_taints = ["workload.sas.com/class=stateless:NoSchedule"]
    node_labels = { "workload.sas.com/class" = "stateless" }
  }
  stateful = {
    ip_addresses = [
      "FIXME-STATEFUL-1",
    ]
    node_taints = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = { "workload.sas.com/class" = "stateful" }
  }
}

# ****************  OPTIONAL — JUMP SERVER  ****************
create_jump = false
# jump_ip   = "FIXME"  # Uncomment and set if create_jump = true

# ****************  OPTIONAL — NFS SERVER  ****************
create_nfs = false
# nfs_ip    = "FIXME"  # Uncomment and set if create_nfs = true

# ****************  OPTIONAL — CONTAINER REGISTRY  ****************
create_cr = false
# cr_ip     = "FIXME"  # Uncomment and set if create_cr = true

# ****************  OPTIONAL — KUBERNETES SETTINGS  ****************
# cluster_version     = "1.35.0"
# cluster_cni         = "calico"
# cluster_cni_version = "3.32.1"
# cluster_cri         = "containerd"
# cluster_cri_version = "2.2.2"
# cluster_lb_type     = "kube_vip"

# ****************  OPTIONAL — POSTGRES SERVERS  ****************
# postgres_servers = {
#   default = {
#     server_ip            = "FIXME"
#     server_version       = 15
#     administrator_login  = "postgres"
#     administrator_password = "FIXME"
#   }
# }

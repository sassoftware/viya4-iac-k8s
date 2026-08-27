# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# vSphere Topology — Sample Input Variables
# =============================================================================
# Usage (topology standalone):
#   cd topologies/vsphere
#   cp provider.tf.example provider.tf   # fill in vSphere credentials
#   terraform init
#   terraform plan  -var-file="sample-input-vsphere.tfvars"
#   terraform apply -var-file="sample-input-vsphere.tfvars"
# =============================================================================

deployment_type = "vsphere"

# Deployment prefix
prefix = "FIXME"

# Ansible credentials
ansible_user     = "FIXME"
ansible_password = "FIXME"

# OS type on template: "ubuntu" or "rocky"
vm_os = "ubuntu"

# System SSH keys directory
system_ssh_keys_dir = "~/.ssh/oss"

# ── vSphere connection ──────────────────────────────────────────────────────
vsphere_server        = "FIXME" # vCenter hostname or IP
vsphere_datacenter    = "FIXME" # vSphere datacenter name
vsphere_datastore     = "FIXME" # Datastore name
vsphere_resource_pool = "FIXME" # Resource pool name
vsphere_folder        = "FIXME" # VM folder name
vsphere_template      = "FIXME" # Template to clone (Ubuntu 22.04 or Rocky 9)
vsphere_network       = "FIXME" # Network name

# ── Network (for static IPs) ────────────────────────────────────────────────
gateway     = "FIXME" # e.g. "192.168.1.1"
netmask     = 24
dns_servers = ["8.8.8.8", "8.8.4.4"]

# ── Kubernetes cluster ──────────────────────────────────────────────────────
cluster_version        = "1.35.0"
cluster_cni            = "calico"
cluster_cni_version    = "3.32.1"
cluster_cri            = "containerd"
cluster_cri_version    = "2.2.2"
cluster_service_subnet = "10.43.0.0/16"
cluster_pod_subnet     = "10.42.0.0/16"
cluster_domain         = "FIXME" # e.g. "example.com"
cluster_vip_ip         = "FIXME" # Available IP for kube-vip HA
cluster_vip_fqdn       = "FIXME" # e.g. "mycluster-vip.example.com"
cluster_vip_version    = "0.7.1"
cluster_lb_type        = "kube_vip"
cluster_lb_addresses   = []

control_plane_ssh_key_name = "cp_ssh"

# ── Node pools ──────────────────────────────────────────────────────────────
node_pools = {
  control_plane = {
    count        = 3
    cpus         = 4
    memory       = 8192
    os_disk      = 100
    misc_disks   = []
    ip_addresses = ["FIXME-CP-1", "FIXME-CP-2", "FIXME-CP-3"]
    node_taints  = []
    node_labels  = {}
  }
  system = {
    count        = 1
    cpus         = 8
    memory       = 65536
    os_disk      = 100
    misc_disks   = []
    ip_addresses = ["FIXME-SYS-1"]
    node_taints  = []
    node_labels  = { "kubernetes.azure.com/mode" = "system" }
  }
  cas = {
    count        = 3
    cpus         = 16
    memory       = 131072
    os_disk      = 350
    misc_disks   = [150, 150]
    ip_addresses = []
    node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels  = { "workload.sas.com/class" = "cas" }
  }
  compute = {
    count        = 5
    cpus         = 24
    memory       = 131072
    os_disk      = 350
    misc_disks   = [150]
    ip_addresses = []
    node_taints  = []
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  }
}

# ── Optional servers ────────────────────────────────────────────────────────
create_jump    = true
jump_ip        = "FIXME"
jump_num_cpu   = 4
jump_memory    = 8092
jump_disk_size = 100

create_nfs    = true
nfs_ip        = "FIXME"
nfs_num_cpu   = 4
nfs_memory    = 16384
nfs_disk_size = 400

create_cr = false

# ── Postgres ────────────────────────────────────────────────────────────────
# postgres_servers = {
#   default = {
#     server_num_cpu         = 4
#     server_memory          = 16384
#     server_disk_size       = 128
#     server_ip              = "FIXME"
#     server_version         = 15
#     server_ssl             = "off"
#     administrator_login    = "postgres"
#     administrator_password = "FIXME"
#   }
# }

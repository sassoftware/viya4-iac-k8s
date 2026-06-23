# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# OpenStack (HPOS) Topology — Sample Input Variables
# =============================================================================
# Customize this file with your actual OpenStack environment values.
#
# Usage (from repo root — recommended):
#   terraform init
#   terraform plan  -var-file="topologies/openstack/sample-input-openstack.tfvars"
#   terraform apply -var-file="topologies/openstack/sample-input-openstack.tfvars"
#
# Usage (topology standalone):
#   cd topologies/openstack
#   cp provider.tf.example provider.tf   # fill in auth details or use OS_* env vars
#   terraform init
#   terraform plan  -var-file="sample-input-openstack.tfvars"
#   terraform apply -var-file="sample-input-openstack.tfvars"
#
# With oss-k8s.sh:
#   SYSTEM=openstack ./oss-k8s.sh -c -v terraform.tfvars
# =============================================================================

# ****************  REQUIRED VARIABLES  ****************

# Deployment type — selects OpenStack topology at root dispatcher level
deployment_type = "openstack"

# Cluster prefix — used in naming all cloud resources (e.g. "myteam-oss-*")
prefix = "myteam"

# OpenStack Auth — recommended: source your RC file or set OS_* environment variables:
#
#   export TF_VAR_openstack_auth_url=$OS_AUTH_URL
#   export TF_VAR_openstack_user_name=$OS_USERNAME
#   export TF_VAR_openstack_password=$OS_PASSWORD
#   export TF_VAR_openstack_tenant_name=$OS_PROJECT_NAME
#   export TF_VAR_openstack_domain_name=$OS_USER_DOMAIN_NAME
#   export TF_VAR_openstack_region=$OS_REGION_NAME
#
openstack_auth_url    = "https://openstack.example.com:5000/v3"
openstack_tenant_name = "myproject"
openstack_region      = "RegionOne"
openstack_domain_name = "Default"

# OpenStack network to attach all VMs to
openstack_network_name = "k8s-network"

# Floating IP pool — used to allocate the control plane VIP and node floating IPs.
# Set to null if floating IPs are not required (use static ip_addresses instead).
openstack_floating_ip_pool = "public"

# Skip TLS verification for self-signed/internal-CA OpenStack endpoints (e.g. HPOS).
# Set to false and provide openstack_cacert_file if your endpoint has a trusted cert.
openstack_insecure = true

# Glance image used for all VMs
openstack_image_name = "Ubuntu 22.04 LTS"

# Existing Nova keypair name (created separately via OpenStack CLI or Horizon)
openstack_ssh_keypair = "myteam-keypair"

# Security groups applied to every VM
openstack_security_groups = ["default", "k8s"]

# Default Nova flavor — overridden per pool via the 'flavor' key in node_pools
openstack_flavor_defaults = "m1.large"

# ****************  REQUIRED VARIABLES  ****************

# **************  RECOMMENDED VARIABLES  ***************

# Ansible credentials
ansible_user = "ubuntu"

# Directory containing SSH public keys added to each node's authorized_keys
system_ssh_keys_dir = "~/.ssh"

# Kubernetes cluster VIP — pre-allocated floating IP registered in DNS
# Run: openstack floating ip create <network> to allocate one
# Then register it: <prefix>-vip.unx.sas.com  →  <floating_ip>
cluster_vip_ip   = null # e.g. "10.119.130.100"
cluster_vip_fqdn = null # e.g. "myteam-vip.unx.sas.com"

# Kubernetes component versions
cluster_version     = "1.34.6"
cluster_cni         = "calico"
cluster_cni_version = "3.30.3"
cluster_cri         = "containerd"
cluster_cri_version = "2.2.2"
cluster_vip_version = "0.7.1"
cluster_lb_type     = "kube_vip"

# Pre-allocated floating IP for the kube-vip cloud provider (LoadBalancer services)
# cluster_lb_addresses = ["range-global: 10.119.130.101-10.119.130.101"]

# Node pools — 'count' creates DHCP VMs; 'ip_addresses' uses static IPs.
# 'flavor' overrides openstack_flavor_defaults for that pool.
node_pools = {
  control_plane = {
    count       = 3
    flavor      = "m1.xlarge"
    os_disk     = 100
    misc_disks  = []
    node_taints = ["node-role.kubernetes.io/control-plane:NoSchedule"]
    node_labels = {}
  }
  system = {
    count       = 3
    flavor      = "m1.2xlarge"
    os_disk     = 100
    misc_disks  = []
    node_taints = []
    node_labels = {
      "workload.sas.com/class" = "system"
    }
  }
  cas = {
    count       = 3
    flavor      = "m1.4xlarge"
    os_disk     = 100
    misc_disks  = []
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  }
}

# Optional: Jump server
# create_jump    = true
# jump_disk_size = 100

# Optional: NFS server
# create_nfs    = true
# nfs_disk_size = 400

# **************  RECOMMENDED VARIABLES  ***************

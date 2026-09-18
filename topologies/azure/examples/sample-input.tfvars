# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Azure Topology — Sample Input Variables
# =============================================================================
# Customize this file with your actual Azure environment values.
#
# Usage (from repo root — recommended):
#   terraform init
#   terraform plan  -var-file="topologies/azure/examples/sample-input-minimal.tfvars"
#   terraform apply -var-file="topologies/azure/examples/sample-input-minimal.tfvars"
#
# Usage (topology standalone — each topology runs independently):
#   cd topologies/azure
#   terraform init
#   terraform plan  -var-file="examples/sample-input-minimal.tfvars"
#   terraform apply -var-file="examples/sample-input-minimal.tfvars"
# =============================================================================

# ****************  REQUIRED VARIABLES  ****************

# Deployment type (selects which topology module is used at root level)
deployment_type = "azure"
tags = {}

# Azure resource settings
azure_resource_group = "my-k8s-single-cp-rg"
azure_location       = "eastus"

# Cluster prefix - used in naming all cloud resources
prefix = "my-k8s-single-cp"

# SSH public key for VM access (path inside container where ~/.ssh is mounted)
ssh_public_key = "~/.ssh/id_rsa.pub"

# Azure Authentication - DO NOT COMMIT SECRETS TO VERSION CONTROL
# Recommended: Set via environment variables:
#
#   export TF_VAR_azure_subscription_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_tenant_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_client_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_client_secret="your-secret-here"
#

azure_use_msi = false

# **************  RECOMMENDED  VARIABLES  ***************
# Azure Networking
azure_vnet_address_space = "192.168.0.0/16"

azure_subnets = {
  k8s = {
    prefixes          = ["192.168.0.0/22"]
    service_endpoints = []
  }
  misc = {
    prefixes          = ["192.168.4.0/24"]
    service_endpoints = []
  }
}

# Security - restrict access to your IPs
azure_default_public_access_cidrs = []

azure_vm_public_ip_enabled   = true
azure_accelerated_networking = true
azure_create_nsg_rules       = true

# ==========================================
# Cluster Node Pools
# ==========================================

node_pools = {
  control_plane = {
    count        = 1
    machine_type = "Standard_D4s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = ["node-role.kubernetes.io/control-plane:NoSchedule"]
    node_labels  = {}
  },
  system = {
    count        = 1
    machine_type = "Standard_D8s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = []
    node_labels = {
      "kubernetes.azure.com/mode" = "system"
    }
  },
  cas = {
    count        = 1
    machine_type = "Standard_E16s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },
  generic = {
    count        = 2
    machine_type = "Standard_D16s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = []
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  }
}

# ==========================================
# Infrastructure VMs
# ==========================================

create_jump       = true
jump_machine_type = "Standard_D2ls_v5"
jump_os_disk      = 64

create_nfs       = true
nfs_machine_type = "Standard_D4s_v5"
nfs_os_disk      = 100
nfs_data_disks   = [256]

# ==========================================
# Kubernetes Configuration
# ==========================================

cluster_version        = "1.35"
cluster_cni            = "calico"
cluster_cni_version    = "3.30.3"
cluster_cri            = "containerd"
cluster_cri_version    = "1.7.24"
cluster_service_subnet = "10.43.0.0/16"
cluster_pod_subnet     = "10.42.0.0/16"

# kube-vip (leave empty for Azure — Azure LB provides HA)
# cluster_vip_ip   = ""
# cluster_vip_fqdn = ""

# **************  RECOMMENDED  VARIABLES  ***************
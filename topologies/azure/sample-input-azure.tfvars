# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Azure Topology — Sample Input Variables
# =============================================================================
# Customize this file with your actual Azure environment values.
#
# Usage (from repo root — recommended):
#   terraform init
#   terraform plan  -var-file="topologies/azure/sample-input-azure.tfvars"
#   terraform apply -var-file="topologies/azure/sample-input-azure.tfvars"
#
# Usage (topology standalone — each topology runs independently):
#   cd topologies/azure
#   terraform init
#   terraform plan  -var-file="sample-input-azure.tfvars"
#   terraform apply -var-file="sample-input-azure.tfvars"
# =============================================================================

# ****************  REQUIRED VARIABLES  ****************

# Deployment type (selects which topology module is used at root level)
deployment_type = "azure"

# Azure resource settings
azure_resource_group = "my-k8s-resource-group"
azure_location       = "eastus"

# Cluster prefix - used in naming all cloud resources
prefix = "my-k8s"

# SSH public key for VM access
# ssh_public_key = "~/.ssh/id_rsa.pub"

# Azure Authentication - DO NOT COMMIT SECRETS TO VERSION CONTROL
# Recommended: Set via environment variables:
#
#   export TF_VAR_azure_subscription_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_tenant_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_client_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_client_secret="your-secret-here"
#
# Or use Managed Identity (when running on an Azure VM):
#   azure_use_msi = true

# ****************  REQUIRED VARIABLES  ****************

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
azure_default_public_access_cidrs = [
  # "203.0.113.0/24"  # Your office/VPN network
]

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
    data_disks   = [512, 512]
    node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },
  generic = {
    count        = 1
    machine_type = "Standard_D16s_v5"
    os_disk      = 100
    data_disks   = [256]
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
jump_machine_type = "Standard_B2s"
jump_os_disk      = 64

create_nfs       = true
nfs_machine_type = "Standard_D4s_v5"
nfs_os_disk      = 100
nfs_data_disks   = [256, 256, 256, 256]

# ==========================================
# Kubernetes Configuration
# ==========================================

cluster_version        = "1.35.3"
azure_ccm_version      = "1.33.1"   # Azure CCM — released independently of Kubernetes
cluster_cni            = "calico"
cluster_cni_version    = "3.30.3"
cluster_cri            = "containerd"
cluster_cri_version    = "1.7.24"
cluster_service_subnet = "10.43.0.0/16"
cluster_pod_subnet     = "10.42.0.0/16"

cluster_lb_type = "kube_vip"
# cluster_vip_ip   = "192.168.4.100"
# cluster_vip_fqdn = "k8s.example.com"

# **************  RECOMMENDED  VARIABLES  ***************

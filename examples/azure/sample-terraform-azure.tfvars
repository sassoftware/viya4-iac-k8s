# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# !NOTE! - These variables are examples for Azure deployment.
# Customize this file to add any variables from 'CONFIG-VARS.md' whose default
# values you want to change.

# ****************  REQUIRED VARIABLES  ****************
# These required variables' values MUST be provided by the User

# Deployment type
deployment_type = "azure"

# Azure Authentication - DO NOT COMMIT SECRETS TO VERSION CONTROL
# It is HIGHLY RECOMMENDED to use environment variables instead:
#
# export TF_VAR_azure_subscription_id="00000000-0000-0000-0000-000000000000"
# export TF_VAR_azure_tenant_id="00000000-0000-0000-0000-000000000000"
# export TF_VAR_azure_client_id="00000000-0000-0000-0000-000000000000"
# export TF_VAR_azure_client_secret="your-secret-here"
#
# If you must use this file (NOT recommended for production):
# azure_subscription_id = "00000000-0000-0000-0000-000000000000"
# azure_tenant_id       = "00000000-0000-0000-0000-000000000000"
# azure_client_id       = "00000000-0000-0000-0000-000000000000"
# azure_client_secret   = "your-secret-here"

# Azure resource settings
azure_resource_group = "my-k8s-resource-group"
azure_location       = "eastus"  # Options: eastus, westus2, centralus, etc.

# ****************  REQUIRED VARIABLES  ****************

# **************  RECOMMENDED  VARIABLES  ***************

# Azure Networking Configuration
# VNet and Subnets will be created with these defaults if not using existing network
azure_vnet_address_space = "192.168.0.0/16"

azure_subnets = {
  k8s = {
    prefixes          = ["192.168.0.0/22"]  # 1024 IPs for Kubernetes nodes
    service_endpoints = []
  }
  misc = {
    prefixes          = ["192.168.4.0/24"]  # 256 IPs for jump box, NFS, etc.
    service_endpoints = []
  }
}

# Security: Define which IP addresses can access your infrastructure
# IMPORTANT: Replace with your specific IP addresses for production
# Example: Your office network, VPN, etc.
azure_default_public_access_cidrs = [
  # "203.0.113.0/24"  # Example: Your office network
  # "198.51.100.0/24" # Example: Your VPN network
]

# Network features
azure_vm_public_ip_enabled    = true   # Enable public IPs for jump box and NFS
azure_accelerated_networking  = true   # Enable accelerated networking for better performance
azure_create_nsg_rules        = true   # Auto-create security rules for SSH, K8s API, etc.

# Optional: Use existing VNet and NSG (Bring Your Own Network)
# Uncomment and configure if you want to use existing network resources
# azure_vnet_name                = "my-existing-vnet"
# azure_vnet_resource_group_name = "my-network-rg"
# azure_nsg_name                 = "my-existing-nsg"
# azure_subnet_names = {
#   k8s  = "my-k8s-subnet"
#   misc = "my-misc-subnet"
# }

# Optional: Configure specific access CIDRs for different resource types
# If not specified, azure_default_public_access_cidrs will be used
# azure_vm_public_access_cidrs              = ["203.0.113.0/24"]  # SSH access to VMs
# azure_cluster_endpoint_public_access_cidrs = ["203.0.113.0/24"]  # K8s API access

# Optional: Custom DNS servers
# azure_use_custom_dns      = true
# azure_custom_dns_servers  = ["10.0.0.4", "10.0.0.5"]

# ==========================================
# Kubernetes-Specific Network Configuration
# ==========================================

# The Azure network module automatically configures NSG rules for Kubernetes ports:
#
# Port        Purpose                      Access Level
# -------     --------------------------   ----------------------------------------
# 22          SSH to VMs                   Restricted by azure_vm_public_access_cidrs
# 6443        Kubernetes API Server        Restricted by azure_cluster_endpoint_public_access_cidrs
# 10250       Kubelet API                  Internal VNet only (automatic)
# 10256       kube-proxy health checks     Internal VNet only (automatic)
# 5473        Calico Typha (CNI)           Internal VNet only (automatic)
# 179         BGP (Calico routing)         Internal VNet only (automatic)
# 2379-2380   etcd server                  Internal VNet only (automatic)
# 30000-32767 NodePort Services            Optional - configure below

# NodePort Services Access (Optional)
# Uncomment if you plan to use NodePort services and need external access
# WARNING: Be restrictive with NodePort access - consider using LoadBalancer/Ingress instead
# azure_nodeport_source_cidrs = [
#   "203.0.113.0/24"  # Example: Specific network that needs NodePort access
# ]

# ==========================================
# Network Planning Recommendations
# ==========================================

# VNet Size Guidelines:
# - Small cluster (< 20 nodes):     /20 or /16 (4K-65K IPs)
# - Medium cluster (20-100 nodes):  /16 (65K IPs)  
# - Large cluster (100+ nodes):     /12 or larger (1M+ IPs)

# Subnet Size Guidelines:
# - k8s subnet (nodes):   
#     Small: /22 (1024 IPs), Medium: /20 (4096 IPs), Large: /18+ (16K+ IPs)
# - misc subnet (infra):  
#     /24 (256 IPs) usually sufficient for jump box, NFS, container registry

# Production Cluster Example (50 nodes):
# azure_vnet_address_space = "10.100.0.0/16"
# azure_subnets = {
#   k8s = {
#     prefixes          = ["10.100.0.0/20"]   # 4096 IPs for K8s nodes and pods
#     service_endpoints = []
#   }
#   misc = {
#     prefixes          = ["10.100.16.0/24"]  # 256 IPs for infrastructure
#     service_endpoints = []
#   }
# }

# ==========================================
# Security Best Practices
# ==========================================

# 1. SSH Access - Restrict to your management network only
#    ✓ Good: azure_vm_public_access_cidrs = ["203.0.113.0/24"]
#    ✗ Bad:  azure_vm_public_access_cidrs = ["0.0.0.0/0"]

# 2. Kubernetes API Access - Limit to authorized networks
#    ✓ Good: azure_cluster_endpoint_public_access_cidrs = ["203.0.113.0/24", "198.51.100.0/24"]
#    ✗ Bad:  azure_cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

# 3. Internal Ports - Automatically secured to VNet only
#    Ports 10250, 10256, 5473, 179, 2379-2380 are restricted to VNet internal traffic
#    No configuration needed - this is handled automatically by the module

# 4. NodePort Services - Avoid if possible, use LoadBalancer/Ingress instead
#    If needed, restrict to specific CIDRs

# Alternative: Use Managed Identity (when running Terraform on an Azure VM)
# This is more secure than using a Service Principal
# azure_use_msi = true

# NOTE: When using Managed Identity, you still need to provide:
# - azure_subscription_id
# - azure_tenant_id
# But you do NOT need azure_client_id or azure_client_secret

# **************  RECOMMENDED  VARIABLES  ***************

# ==========================================
# Cluster Node Pools Configuration
# ==========================================
# 
# Your cluster requires:
#   - control_plane: Kubernetes control plane (1 or 3 for HA with kube-vip)
#   - system:        Kubernetes infrastructure workloads (DNS, metrics, CNI, ingress)
#   - cas:           Optional - Analytics workloads (comment out to disable)
#   - generic:       General purpose workloads (compute, stateless, stateful apps)
#
# Azure VM Sizing Reference:
#   D-series (General compute):   D2s_v5 (2v/8GB) to D64s_v5 (64v/256GB)
#   E-series (Memory-optimized):  E4s_v5 (4v/32GB) to E80s_v5 (80v/504GB)
#
# Data Disks:
#   - cas node:     2x512GB for memory spill
#   - generic node: 1x256GB for cache/temp storage
#   - system node:  No additional disks (OS only)
#   - nfs server:   4x1TB for RAID configuration

node_pools = {
  # REQUIRED: Control Plane - Kubernetes etcd and API server
  # Use count=1 for single-master or count=3 for HA (with kube-vip)
  control_plane = {
    count        = 1
    machine_type = "Standard_D4s_v5"      # 4 vCPU, 16 GB RAM
    os_disk      = 100                    # 100 GB OS disk
    data_disks   = []                     # No additional disks
    node_taints  = ["node-role.kubernetes.io/control-plane:NoSchedule"]
    node_labels  = {}
  },

  # REQUIRED: System Node - Infrastructure workloads
  # Runs: DNS, kube-proxy, metrics-server, CNI (Calico), ingress controller
  system = {
    count        = 1
    machine_type = "Standard_D8s_v5"      # 8 vCPU, 32 GB RAM
    os_disk      = 100                    # 100 GB OS disk
    data_disks   = []                     # No additional disks
    node_taints  = []
    node_labels  = {
      "kubernetes.azure.com/mode" = "system"
    }
  },

  # OPTIONAL: CAS Node - Analytics workloads (Memory-optimized)
  # Comment out this block if you don't need CAS workloads
  cas = {
    count        = 1
    machine_type = "Standard_E16s_v5"     # 16 vCPU, 128 GB RAM (memory-optimized)
    os_disk      = 100                    # 100 GB OS disk
    data_disks   = [512, 512]             # 2x512GB for memory spill
    node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels  = {
      "workload.sas.com/class" = "cas"
    }
  },

  # General Purpose Node Pool
  # Handles: compute, stateless, stateful workloads
  generic = {
    count        = 1
    machine_type = "Standard_D16s_v5"     # 16 vCPU, 64 GB RAM
    os_disk      = 100                    # 100 GB OS disk
    data_disks   = [256]                  # 1x256GB for cache/temp data
    node_taints  = []
    node_labels  = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  }
}

# ==========================================
# Infrastructure VMs (Non-Kubernetes)
# ==========================================

# Jump Box / Bastion Host
create_jump        = true
jump_machine_type  = "Standard_B2s"       # 2 vCPU, 4 GB RAM
jump_os_disk       = 64                   # 64 GB OS disk

# NFS Server (for Persistent Volumes)
create_nfs         = true
nfs_machine_type   = "Standard_D4s_v5"    # 4 vCPU, 16 GB RAM
nfs_os_disk        = 100                  # 100 GB OS disk
nfs_data_disks     = [1024, 1024, 1024, 1024]  # 4x1TB for RAID1


# ==========================================
# Example Configurations
# ==========================================

# Example 1: Minimal/Development (smallest viable setup)
# node_pools = {
#   control_plane = {
#     count        = 1
#     machine_type = "Standard_D2s_v5"      # 2 vCPU, 8 GB
#     os_disk      = 50
#     data_disks   = []
#     node_taints  = []
#     node_labels  = {}
#   },
#   system = {
#     count        = 1
#     machine_type = "Standard_D2s_v5"      # 2 vCPU, 8 GB
#     os_disk      = 50
#     data_disks   = []
#     node_taints  = []
#     node_labels  = {"kubernetes.azure.com/mode" = "system"}
#   },
#   generic = {
#     count        = 2
#     machine_type = "Standard_D4s_v5"      # 4 vCPU, 16 GB
#     os_disk      = 100
#     data_disks   = [256]
#     node_taints  = []
#     node_labels  = {}
#   }
# }

# Example 2: Production with HA Control Plane
# node_pools = {
#   control_plane = {
#     count        = 3                      # HA with kube-vip
#     machine_type = "Standard_D4s_v5"
#     os_disk      = 150
#     data_disks   = []
#     node_taints  = []
#     node_labels  = {}
#   },
#   system = {
#     count        = 2
#     machine_type = "Standard_D8s_v5"
#     os_disk      = 150
#     data_disks   = []
#     node_taints  = []
#     node_labels  = {"kubernetes.azure.com/mode" = "system"}
#   },
#   cas = {
#     count        = 2
#     machine_type = "Standard_E20s_v5"     # 20 vCPU, 160 GB (larger CAS)
#     os_disk      = 200
#     data_disks   = [500, 500]
#     node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
#     node_labels  = {"workload.sas.com/class" = "cas"}
#   },
#   generic = {
#     count        = 5
#     machine_type = "Standard_D16s_v5"
#     os_disk      = 200
#     data_disks   = [512]
#     node_taints  = []
#     node_labels  = {"workload.sas.com/class" = "compute"}
#   }
# }

# Example 3: Without CAS (Programming-only deployment)
# node_pools = {
#   control_plane = {
#     count        = 1
#     machine_type = "Standard_D4s_v5"
#     os_disk      = 100
#     data_disks   = []
#     node_taints  = []
#     node_labels  = {}
#   },
#   system = {
#     count        = 1
#     machine_type = "Standard_D8s_v5"
#     os_disk      = 100
#     data_disks   = []
#     node_taints  = []
#     node_labels  = {"kubernetes.azure.com/mode" = "system"}
#   },
#   generic = {
#     count        = 3
#     machine_type = "Standard_D8s_v5"
#     os_disk      = 150
#     data_disks   = [256]
#     node_taints  = []
#     node_labels  = {"workload.sas.com/class" = "compute"}
#   }
# }

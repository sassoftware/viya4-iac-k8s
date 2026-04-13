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

# Alternative: Use Managed Identity (when running Terraform on an Azure VM)
# This is more secure than using a Service Principal
# azure_use_msi = true

# NOTE: When using Managed Identity, you still need to provide:
# - azure_subscription_id
# - azure_tenant_id
# But you do NOT need azure_client_id or azure_client_secret

# **************  RECOMMENDED  VARIABLES  ***************

# Additional configuration examples:
# See CONFIG-VARS.md for all available variables

# Example: Node pools configuration
# node_pools = {
#   control_plane = {
#     count = 3
#     cpus = 4
#     memory = 8192
#     os_disk = 100
#   }
#   system = {
#     count = 3
#     cpus = 8
#     memory = 16384
#     os_disk = 200
#     node_labels = {
#       "kubernetes.azure.com/mode" = "system"
#     }
#   }
#   compute = {
#     count = 2
#     cpus = 16
#     memory = 32768
#     os_disk = 200
#   }
# }

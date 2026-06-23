# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Deployment Type
#
variable "deployment_type" {
  description = "Infrastructure deployment type. Must be 'azure' for this topology."
  type        = string
  default     = "azure"

  validation {
    condition     = lower(var.deployment_type) == "azure"
    error_message = "ERROR: deployment_type must be 'azure' for the Azure topology."
  }
}

#
# Generic
#
variable "prefix" {
  description = "A prefix used in the name for all cloud resources created by this script. The prefix string must start with lowercase letter and contain only lowercase alphanumeric characters and hyphen or dash(-), but can not start or end with '-'."
  type        = string
}

variable "ansible_user" {
  type    = string
  default = null
}

variable "ansible_password" {
  type    = string
  default = null
}

variable "system_ssh_keys_dir" {
  type    = string
  default = "~/.ssh"
}

variable "inventory" {
  type        = string
  description = "File name and location of the generated inventory file"
  default     = "inventory"
}

variable "ansible_vars" {
  type        = string
  description = "File name and location of the generated ansible-vars.yaml file"
  default     = "ansible-vars.yaml"
}

variable "tags" {
  description = "Tags to apply to all Azure resources"
  type        = map(string)
  default     = {}
}

variable "iac_tooling" {
  description = "Value used to identify the tooling used to generate this provider's infrastructure"
  type        = string
  default     = "terraform"
}

#
# Azure Authentication
#
variable "azure_subscription_id" {
  type        = string
  description = "The ID of the Azure Subscription."
  default     = null
}

variable "azure_tenant_id" {
  type        = string
  description = "The ID of the Tenant to which the subscription belongs."
  default     = null
}

variable "azure_client_id" {
  type        = string
  description = "The Client ID for the Service Principal."
  default     = null
  sensitive   = true
}

variable "azure_client_secret" {
  type        = string
  description = "The Client Secret for the Service Principal."
  default     = null
  sensitive   = true
}

variable "azure_use_msi" {
  type        = bool
  description = "Use Managed Identity for Authentication (Azure VMs only)."
  default     = false
}

#
# Azure Resource Configuration
#
variable "azure_resource_group" {
  type        = string
  description = "Azure resource group name. Will be created by Terraform."

  validation {
    condition     = var.azure_resource_group != null
    error_message = "ERROR: azure_resource_group must be specified."
  }
}

variable "azure_location" {
  type        = string
  description = "The Azure Region to provision resources."
  default     = "eastus"
}

#
# Azure Networking
#
variable "azure_vnet_resource_group_name" {
  type        = string
  description = "Name of pre-existing resource group containing the VNet. Leave blank to use the main resource group."
  default     = null
}

variable "azure_vnet_name" {
  type        = string
  description = "Name of pre-existing VNet. Leave blank to create a new VNet."
  default     = null
}

variable "azure_vnet_address_space" {
  type        = string
  description = "Address space for the VNet to be created. Only used if azure_vnet_name is not specified."
  default     = "192.168.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.azure_vnet_address_space))
    error_message = "ERROR: azure_vnet_address_space must be a valid CIDR notation."
  }
}

variable "azure_subnet_names" {
  description = "Map subnet usage roles to existing subnet names. Example: {k8s = 'my-k8s-subnet', misc = 'my-misc-subnet'}"
  type        = map(string)
  default     = {}
}

variable "azure_subnets" {
  description = "Subnets to be created and their CIDR prefixes. Only used if azure_vnet_name is not specified."
  type = map(object({
    prefixes          = list(string)
    service_endpoints = list(string)
  }))
  default = {
    k8s = {
      prefixes          = ["192.168.0.0/22"]
      service_endpoints = []
    }
    misc = {
      prefixes          = ["192.168.4.0/24"]
      service_endpoints = []
    }
  }

  validation {
    condition = alltrue([
      for subnet_key, subnet in var.azure_subnets : alltrue([
        for prefix in subnet.prefixes : can(cidrnetmask(prefix))
      ])
    ])
    error_message = "ERROR: All subnet prefixes must be valid CIDR notations."
  }
}

variable "azure_nsg_name" {
  type        = string
  description = "Name of pre-existing k8s Network Security Group. Leave blank to create a new NSG."
  default     = null
}

variable "azure_misc_nsg_name" {
  type        = string
  description = "Name of pre-existing misc (jump/nfs) Network Security Group. Leave blank to create a new NSG."
  default     = null
}

variable "azure_create_nsg_rules" {
  type        = bool
  description = "Create default NSG rules for SSH, Kubernetes API, etc. Set to false if using existing NSG."
  default     = true
}

variable "azure_default_public_access_cidrs" {
  description = "Default list of CIDRs allowed to access Azure resources (VMs, etc.)."
  type        = list(string)
  default     = null

  validation {
    condition = var.azure_default_public_access_cidrs == null ? true : alltrue([
      for cidr in var.azure_default_public_access_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "ERROR: All CIDRs in azure_default_public_access_cidrs must be valid CIDR notations."
  }
}

variable "azure_vm_public_access_cidrs" {
  description = "List of CIDRs allowed to SSH into VMs. Defaults to azure_default_public_access_cidrs if not specified."
  type        = list(string)
  default     = null

  validation {
    condition = var.azure_vm_public_access_cidrs == null ? true : alltrue([
      for cidr in var.azure_vm_public_access_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "ERROR: All CIDRs in azure_vm_public_access_cidrs must be valid CIDR notations."
  }
}

variable "azure_cluster_endpoint_public_access_cidrs" {
  description = "List of CIDRs allowed to access Kubernetes API endpoint. Defaults to azure_default_public_access_cidrs if not specified."
  type        = list(string)
  default     = null

  validation {
    condition = var.azure_cluster_endpoint_public_access_cidrs == null ? true : alltrue([
      for cidr in var.azure_cluster_endpoint_public_access_cidrs : can(cidrnetmask(cidr))
    ])
    error_message = "ERROR: All CIDRs in azure_cluster_endpoint_public_access_cidrs must be valid CIDR notations."
  }
}

variable "azure_vm_public_ip_enabled" {
  type        = bool
  description = "Enable public IP addresses for VMs (jump box, NFS, etc.)."
  default     = true
}

variable "azure_accelerated_networking" {
  type        = bool
  description = "Enable Azure Accelerated Networking for improved network performance on supported VM sizes."
  default     = true
}

variable "azure_use_custom_dns" {
  type        = bool
  description = "Use custom DNS servers instead of Azure-provided DNS."
  default     = false
}

variable "azure_custom_dns_servers" {
  description = "List of custom DNS server IP addresses for the VNet. Only used if azure_use_custom_dns is true."
  type        = list(string)
  default     = []

  validation {
    condition = var.azure_use_custom_dns == false || (
      var.azure_use_custom_dns && length(var.azure_custom_dns_servers) > 0
    )
    error_message = "ERROR: azure_custom_dns_servers must be provided when azure_use_custom_dns is true."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Path to SSH public key file for VM access (e.g., ~/.ssh/id_rsa.pub)."
  default     = null

  validation {
    condition     = var.ssh_public_key == null ? true : fileexists(var.ssh_public_key)
    error_message = "ssh_public_key file does not exist. Please provide a valid path to your public key file."
  }
}

#
# Kubernetes Cluster
#
variable "cluster_domain" {
  type    = string
  default = null
}

variable "cluster_version" {
  type    = string
  default = "1.35.3"
}

# Azure CCM is released independently of Kubernetes. Pin to the latest tag
# published at mcr.microsoft.com/oss/kubernetes/azure-cloud-controller-manager.
# Override via tfvars when a newer CCM is available for your cluster_version.
variable "azure_ccm_version" {
  type    = string
  default = "1.33.1"
}

variable "cluster_cni" {
  type    = string
  default = "calico"
}

variable "cluster_cni_version" {
  type    = string
  default = "3.30.3"
}

variable "cluster_cri" {
  type    = string
  default = "containerd"
}

variable "cluster_cri_version" {
  type    = string
  default = "1.7.24"
}

variable "cluster_service_subnet" {
  type    = string
  default = "10.43.0.0/16"
}

variable "cluster_pod_subnet" {
  type    = string
  default = "10.42.0.0/16"
}

variable "cluster_vip_version" {
  type    = string
  default = "0.7.1"
}

variable "cluster_vip_ip" {
  type    = string
  default = null
}

variable "cluster_vip_fqdn" {
  type    = string
  default = null
}

variable "cluster_api_internal_ip" {
  description = "Static private IP for the internal API LB frontend. Used as controlPlaneEndpoint for in-cluster HA (avoids Azure LB hairpin)."
  type        = string
  default     = "192.168.0.100"
}

# cluster_lb_type is accepted for interface compatibility with the root module
# dispatcher but is not used for Azure external access.
# Azure uses the azure_api_lb Standard LB for API endpoint; kube-vip/metallb
# is only relevant for on-prem topologies.
variable "cluster_lb_type" {
  type    = string
  default = "kube_vip"

  validation {
    condition     = contains(["kube_vip", "metallb"], lower(var.cluster_lb_type))
    error_message = "ERROR: Valid values for the cluster_lb_type are: kube_vip, metallb"
  }
}

variable "cluster_lb_addresses" {
  type    = list(any)
  default = null
}

#
# Node Pools
#
variable "node_pool_defaults" {
  description = "Map of kubernetes nodes defaults"
  type        = any
  default = {
    cpus         = 2
    memory       = 4096
    os_disk      = 25
    misc_disks   = []
    count        = 0
    ip_addresses = []
    node_taints  = []
    node_labels  = {}
  }
}

variable "node_pools" {
  description = "Map of kubernetes nodes"
  type        = any
  default     = null

  validation {
    condition     = var.node_pools != null ? true : false
    error_message = "ERROR: You have not defined any nodes for your cluster. This is a requirement."
  }

  validation {
    condition = var.node_pools != null ? length(var.node_pools) != 0 ? alltrue([
      length(var.node_pools) >= 3,
      length(setintersection(keys(var.node_pools), ["control_plane", "system"])) == 2,
    ]) : false : true
    error_message = "ERROR: You must have at least one control_plane node, one system node, and one other node."
  }
}

variable "control_plane_ssh_key_name" {
  type    = string
  default = "cp_ssh"
}

#
# Jump Server
#
variable "create_jump" {
  type    = bool
  default = false
}

variable "jump_machine_type" {
  type        = string
  description = "Azure VM size for jump server"
  default     = "Standard_D2s_v5"
}

variable "jump_os_disk" {
  type        = number
  description = "OS disk size in GB for jump server"
  default     = 64
}

#
# NFS Server
#
variable "create_nfs" {
  type    = bool
  default = false
}

variable "nfs_machine_type" {
  type        = string
  description = "Azure VM size for NFS server"
  default     = "Standard_D4s_v5"
}

variable "nfs_os_disk" {
  type        = number
  description = "OS disk size in GB for NFS server"
  default     = 100
}

variable "nfs_data_disks" {
  type        = list(number)
  description = "List of data disk sizes in GB for NFS server"
  default     = [1024, 1024, 1024, 1024]
}

#
# Container Registry
#
variable "create_cr" {
  type    = bool
  default = false
}

variable "cr_ip" {
  type    = string
  default = null
}

#
# Postgres
#
variable "postgres_server_defaults" {
  description = ""
  type        = any
  default = {
    server_num_cpu           = 4
    server_memory            = 16384
    server_disk_size         = 128
    server_ip                = ""
    server_version           = 15
    server_ssl               = "off"
    server_ssl_cert_file     = ""
    server_ssl_key_file      = ""
    administrator_login      = "postgres"
    administrator_password   = "my$up3rS3cretPassw0rd"
    postgres_system_settings = [{ name = "max_prepared_transactions", value = "1024" }, { name = "max_connections", value = "1024" }]
  }
}

variable "postgres_servers" {
  description = "Map of PostgreSQL server objects"
  type        = any
  default     = null
  validation {
    condition     = var.postgres_servers == null || can([for pg in keys(var.postgres_servers) : regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", pg)])
    error_message = "ERROR: Postgres Server names must follow a valid naming scheme. Name must consist of lower case alphanumeric characters or '-', and must start and end with an alphanumeric character"
  }
}

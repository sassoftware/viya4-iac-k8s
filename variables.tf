# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Generic
#
variable "deployment_type" {
  type        = string
  description = "Options are: bare_metal, vsphere, or azure"
  default     = "bare_metal"

  validation {
    condition     = contains(["bare_metal", "vsphere", "azure"], var.deployment_type)
    error_message = "ERROR: deployment_type must be one of: bare_metal, vsphere, or azure."
  }
}

#
# Azure
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

variable "azure_resource_group" {
  type        = string
  description = "Azure resource group name. Will be created by Terraform if deployment_type is azure."
  default     = null

  validation {
    condition     = var.deployment_type != "azure" || var.azure_resource_group != null
    error_message = "ERROR: azure_resource_group must be specified when deployment_type is azure."
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
      prefixes          = ["192.168.0.0/22"] # 1024 IPs for K8s nodes
      service_endpoints = []
    }
    misc = {
      prefixes          = ["192.168.4.0/24"] # 256 IPs for jump, NFS, etc.
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
  description = "Default list of CIDRs allowed to access Azure resources (VMs, etc.). Use ['0.0.0.0/0'] for public access (NOT recommended for production)."
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
  description = "List of CIDRs allowed to SSH into VMs (jump box, NFS, etc.). Defaults to azure_default_public_access_cidrs if not specified."
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
  description = "Enable public IP addresses for VMs (jump box, NFS, etc.). Required if accessing from external networks."
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

variable "tags" {
  description = "Tags to apply to all Azure resources"
  type        = map(string)
  default     = {}
}

variable "ssh_public_key" {
  type        = string
  description = "Path to SSH public key file for VM access (e.g., ~/.ssh/id_rsa.pub). Required for Azure deployments."
  default     = null

  validation {
    condition     = var.ssh_public_key == null ? true : fileexists(var.ssh_public_key)
    error_message = "ssh_public_key file does not exist. Please provide a valid path to your public key file."
  }
}

#
# vSphere
#
variable "vsphere_server" {
  type        = string
  description = "This is the vSphere server for the environment."
  default     = null
}

variable "vsphere_user" {
  type        = string
  description = "vSphere server user for the environment."
  default     = null
}

variable "vsphere_password" {
  type        = string
  description = "vSphere server password"
  default     = null
}

variable "vsphere_datacenter" {
  type        = string
  description = "This is the name of the vSphere data center."
  default     = null
}

variable "vsphere_datastore" {
  type        = string
  description = "This is the name of the vSphere data store."
  default     = null
}

variable "vsphere_resource_pool" {
  type        = string
  description = "This is the name of the vSphere resource pool."
  default     = null
}

variable "vsphere_folder" {
  type        = string
  description = "This is the name of the vSphere folder."
  default     = null
}

variable "vsphere_template" {
  type        = string
  description = "This is the name of the VM template to clone."
  default     = null
}

variable "vsphere_network" {
  type        = string
  description = "This is the name of the publicly accessible network for cluster ingress and access."
  default     = null
}

# 
# Misc.
#
variable "gateway" {
  type        = string
  description = "Gateway IP (if using static ips)"
  default     = ""
}

variable "nat_ip" {
  type        = string
  description = "NAT IP"
  default     = null
}

variable "netmask" {
  type        = number
  description = "Netmask (if using static ips)"
  default     = 16
}

variable "dns_servers" {
  description = "DNS servers (if using static ips)"
  default     = ["10.19.1.24", "10.36.1.53"]
  type        = list(any)
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

#
# Systems
#
variable "control_plane_ssh_key_name" {
  type    = string
  default = "cp_ssh"
}
# Node Pools
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

  # Nodes defined
  validation {
    condition     = var.node_pools != null ? true : false
    error_message = "ERROR: You have not defined any nodes for your cluster. This is a requirement."
  }

  # Node type validation - Must have at least one control_plane node, one system node, and one other node
  validation {
    condition = var.node_pools != null ? length(var.node_pools) != 0 ? alltrue([
      length(var.node_pools) >= 3,
      length(setintersection(keys(var.node_pools), ["control_plane", "system"])) == 2,
    ]) : false : true
    error_message = "ERROR: You must have at least one control_plane node, one system node, and one other node."
  }

  # TODO
  # Node count and ip_addresses must not both be null
  validation {
    condition = var.node_pools != null ? length(var.node_pools) != 0 ? alltrue([
      for k, v in var.node_pools : alltrue([
        # lookup(v, "count", false),
        # lookup(v, "ip_addresses", false)
      ])
    ]) : false : true
    error_message = "ERROR: You need to set either the count or ip_addresses value in your node definition."
  }
}

# jump
variable "create_jump" {
  type    = bool
  default = false
}
variable "jump_ip" {
  type    = string
  default = null
}

variable "jump_memory" {
  type    = number
  default = 8092
}

variable "jump_num_cpu" {
  type    = number
  default = 4
}

variable "jump_disk_size" {
  type    = number
  default = 100
}

# Azure-specific jump server variables
variable "jump_machine_type" {
  type        = string
  description = "Azure VM size for jump server (e.g., Standard_D2s_v5)"
  default     = "Standard_D2s_v5"
}

variable "jump_os_disk" {
  type        = number
  description = "OS disk size in GB for jump server"
  default     = 64
}

# nfs
variable "create_nfs" {
  type    = bool
  default = false
}
variable "nfs_ip" {
  type    = string
  default = null
}

variable "nfs_memory" {
  type    = number
  default = 16384
}

variable "nfs_num_cpu" {
  type    = number
  default = 4
}

variable "nfs_disk_size" {
  type    = number
  default = 400
}

# Azure-specific NFS server variables
variable "nfs_machine_type" {
  type        = string
  description = "Azure VM size for NFS server (e.g., Standard_D4s_v5)"
  default     = "Standard_D4s_v5"
}

variable "nfs_os_disk" {
  type        = number
  description = "OS disk size in GB for NFS server"
  default     = 100
}

variable "nfs_data_disks" {
  type        = list(number)
  description = "List of data disk sizes in GB for NFS server (e.g., [1024, 1024, 1024, 1024] for 4x1TB RAID configuration)"
  default     = [1024, 1024, 1024, 1024]
}

# container registry - TODO
variable "create_cr" {
  type    = bool
  default = false
}
variable "cr_ip" {
  type    = string
  default = null
}

variable "cr_memory" {
  type    = number
  default = 8092
}

variable "cr_num_cpu" {
  type    = number
  default = 4
}

variable "cr_disk_size" {
  type    = number
  default = 160
}

# postgres
variable "postgres_server_defaults" {
  description = ""
  type        = any
  default = {
    server_num_cpu           = 4                       # 4 CPUs
    server_memory            = 16384                   # 16 GiB
    server_disk_size         = 128                     # 128 GiB
    server_ip                = ""                      # Assigned values for static IPs
    server_version           = 15                      # PostgreSQL version
    server_ssl               = "off"                   # SSL flag
    server_ssl_cert_file     = ""                      # PostgreSQL SSL certificate file
    server_ssl_key_file      = ""                      # PostgreSQL SSL key file
    administrator_login      = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password   = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
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

# Regex for validation : ^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$

# ==========================================
# PSCLOUD-771: Worker Node Configuration Variables
# ==========================================
# These variables define machine types, disk configurations, and scheduling constraints (taints/labels) for Azure Kubernetes worker nodes

variable "worker_node_template" {
  description = "Template configuration for worker nodes with Azure-specific settings (machine_type, os_disk, data_disks, taints, labels)"
  type = object({
    machine_type = optional(string, "Standard_D4s_v5")
    os_disk      = optional(number, 128)
    data_disks   = optional(list(number), [])
    node_taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    node_labels = optional(map(string), {})
  })
  default = {
    machine_type = "Standard_D4s_v5"
    os_disk      = 128
    data_disks   = []
    node_taints  = []
    node_labels  = {}
  }
}

variable "control_plane_machine_type" {
  description = "Azure VM size for control plane nodes (e.g., Standard_D4s_v5). Should be sized for etcd and API server workloads."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "control_plane_os_disk" {
  description = "OS disk size in GB for control plane nodes"
  type        = number
  default     = 128
}

variable "control_plane_taints" {
  description = "Kubernetes taints for control plane nodes to prevent pod scheduling (e.g., node-role.kubernetes.io/control-plane=:NoSchedule)"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [
    {
      key    = "node-role.kubernetes.io/control-plane"
      value  = ""
      effect = "NoSchedule"
    }
  ]
}

variable "control_plane_labels" {
  description = "Kubernetes labels for control plane nodes for pod scheduling"
  type        = map(string)
  default = {
    "node-role.kubernetes.io/control-plane" = ""
  }
}

variable "system_node_machine_type" {
  description = "Azure VM size for system nodes (e.g., Standard_D4s_v5). These run Kubernetes system components."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "system_node_os_disk" {
  description = "OS disk size in GB for system nodes"
  type        = number
  default     = 128
}

variable "system_node_taints" {
  description = "Kubernetes taints for system nodes (e.g., CriticalAddonsOnly=true:NoSchedule)"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [
    {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NoSchedule"
    }
  ]
}

variable "system_node_labels" {
  description = "Kubernetes labels for system nodes"
  type        = map(string)
  default = {
    "node-role.kubernetes.io/system" = ""
  }
}

variable "cas_node_machine_type" {
  description = "Azure VM size for CAS nodes (e.g., Standard_D32s_v5 or higher). These are memory-intensive."
  type        = string
  default     = "Standard_D32s_v5"
}

variable "cas_node_os_disk" {
  description = "OS disk size in GB for CAS nodes"
  type        = number
  default     = 128
}

variable "cas_node_data_disks" {
  description = "List of data disk sizes in GB for CAS nodes (e.g., [1024, 1024] for 2x1TB storage)"
  type        = list(number)
  default     = []
}

variable "cas_node_taints" {
  description = "Kubernetes taints for CAS nodes to enforce pod affinity (e.g., workload/cas=true:NoSchedule)"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [
    {
      key    = "workload/cas"
      value  = "true"
      effect = "NoSchedule"
    }
  ]
}

variable "cas_node_labels" {
  description = "Kubernetes labels for CAS nodes for pod scheduling"
  type        = map(string)
  default = {
    "workload/cas" = "true"
  }
}

variable "generic_worker_machine_type" {
  description = "Azure VM size for generic worker nodes (e.g., Standard_D4s_v5)"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "generic_worker_os_disk" {
  description = "OS disk size in GB for generic worker nodes"
  type        = number
  default     = 128
}

variable "generic_worker_data_disks" {
  description = "List of data disk sizes in GB for generic worker nodes"
  type        = list(number)
  default     = []
}

variable "generic_worker_labels" {
  description = "Kubernetes labels for generic worker nodes"
  type        = map(string)
  default = {
    "node-role.kubernetes.io/worker" = ""
  }
}

variable "node_taints_enable_cas_only" {
  description = "If true, only CAS nodes have taints. All other worker nodes (control_plane, system, generic) run unrestricted workloads. If false, each node type has specific taints."
  type        = bool
  default     = true
}

# Ansible
variable "ansible_user" {
  type    = string
  default = null
}

variable "ansible_password" {
  type    = string
  default = null
}

# Kubernetes 
variable "prefix" {
  description = "A prefix used in the name for all cloud resources created by this script. The prefix string must start with lowercase letter and contain only lowercase alphanumeric characters and hyphen or dash(-), but can not start or end with '-'."
  type        = string
}

variable "system_ssh_keys_dir" {
  type    = string
  default = "~/.ssh"
}

variable "cluster_domain" {
  type    = string
  default = null
}

variable "cluster_version" {
  type    = string
  default = "1.30.8"
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

variable "iac_tooling" {
  description = "Value used to identify the tooling used to generate this provider's infrastructure"
  type        = string
  default     = "terraform"
}

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Deployment Type
#
variable "deployment_type" {
  description = "Infrastructure deployment type. Supported: 'azure', 'openstack', 'bare_metal', 'vsphere'."
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "openstack", "bare_metal", "vsphere"], lower(var.deployment_type))
    error_message = "deployment_type must be one of: azure, openstack, bare_metal, vsphere."
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
  description = "Azure resource group name. Will be created by Terraform. Required when deployment_type is 'azure'."
  default     = null
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

# Azure Cloud Controller Manager version — released independently of Kubernetes.
# Only consumed by the Azure topology; ignored by other topologies.
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
  default = "3.32.1"
}

variable "cluster_cri" {
  type    = string
  default = "containerd"
}

variable "cluster_cri_version" {
  type    = string
  default = "2.2.2"
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

#
# OpenStack (HPOS) — only used when deployment_type = "openstack"
#
variable "openstack_auth_url" {
  type        = string
  description = "The OpenStack Identity (Keystone) authentication URL."
  default     = null
}

variable "openstack_user_name" {
  type        = string
  description = "The username to authenticate with OpenStack."
  default     = null
}

variable "openstack_password" {
  type        = string
  description = "The password to authenticate with OpenStack."
  default     = null
  sensitive   = true
}

variable "openstack_tenant_name" {
  type        = string
  description = "The OpenStack project/tenant name."
  default     = null
}

variable "openstack_domain_name" {
  type        = string
  description = "The OpenStack domain name (usually 'Default')."
  default     = "Default"
}

variable "openstack_region" {
  type        = string
  description = "The OpenStack region to deploy resources in."
  default     = null
}

variable "openstack_network_name" {
  type        = string
  description = "The name of the OpenStack (Neutron) network to attach VMs to."
  default     = null
}

variable "openstack_floating_ip_pool" {
  type        = string
  description = "The name of the external network / floating-IP pool for VM floating IPs."
  default     = null
}

variable "openstack_image_name" {
  type        = string
  description = "The name of the OpenStack Glance image to use for VMs (e.g. 'Ubuntu 22.04')."
  default     = null
}

variable "openstack_ssh_keypair" {
  type        = string
  description = "Name of the existing OpenStack Nova keypair to inject into VMs."
  default     = null
}

variable "openstack_security_groups" {
  type        = list(string)
  description = "List of OpenStack security group names to apply to every VM."
  default     = ["default"]
}

variable "openstack_availability_zone" {
  type        = string
  description = "OpenStack availability zone in which to create VMs."
  default     = "nova"
}

variable "openstack_insecure" {
  type        = bool
  description = "Set to true to disable TLS certificate verification for the OpenStack endpoint."
  default     = false
}

variable "openstack_cacert_file" {
  type        = string
  description = "Path to a CA certificate file to verify the OpenStack endpoint TLS certificate."
  default     = null
}

variable "openstack_flavor_defaults" {
  type        = string
  description = "Default OpenStack Nova flavor name used when a node pool does not specify its own flavor."
  default     = "m1.large"
}

variable "nat_ip" {
  type        = string
  description = "NAT IP (OpenStack / bare metal)"
  default     = null
}

variable "jump_ip" {
  type        = string
  description = "Pre-allocated IP for the jump server (OpenStack / bare metal with static IPs)."
  default     = null
}

variable "jump_disk_size" {
  type        = number
  description = "Jump server root disk size in GiB."
  default     = 100
}

variable "nfs_ip" {
  type        = string
  description = "Pre-allocated IP for the NFS server (OpenStack / bare metal with static IPs)."
  default     = null
}

variable "nfs_disk_size" {
  type        = number
  description = "NFS server root disk size in GiB."
  default     = 400
}

variable "cr_ip" {
  type        = string
  description = "Pre-allocated IP for the container registry (OpenStack / bare metal with static IPs)."
  default     = null
}

variable "cr_disk_size" {
  type        = number
  description = "Container registry root disk size in GiB."
  default     = 160
}

#
# Bare Metal — only used when deployment_type = "bare_metal"
#
variable "vm_os" {
  type        = string
  description = "Operating system type on bare metal nodes. Choices: ubuntu, rocky. Only used when deployment_type = 'bare_metal'."
  default     = "ubuntu"

  validation {
    condition     = contains(["ubuntu", "rocky"], lower(var.vm_os))
    error_message = "ERROR: vm_os must be 'ubuntu' or 'rocky'."
  }
}

#
# vSphere — only used when deployment_type = "vsphere"
#

variable "vsphere_server" {
  type        = string
  description = "vCenter server hostname or IP address."
  default     = null
}

variable "vsphere_user" {
  type        = string
  description = "vSphere user (e.g. administrator@vsphere.local)."
  default     = null
}

variable "vsphere_password" {
  type        = string
  description = "vSphere password."
  sensitive   = true
  default     = null
}

variable "vsphere_datacenter" {
  type        = string
  description = "vSphere datacenter name."
  default     = null
}

variable "vsphere_datastore" {
  type        = string
  description = "vSphere datastore name."
  default     = null
}

variable "vsphere_resource_pool" {
  type        = string
  description = "vSphere resource pool name."
  default     = null
}

variable "vsphere_folder" {
  type        = string
  description = "vSphere VM folder name."
  default     = null
}

variable "vsphere_template" {
  type        = string
  description = "vSphere template name to clone for new VMs."
  default     = null
}

variable "vsphere_network" {
  type        = string
  description = "vSphere network (port group) name."
  default     = null
}

variable "vsphere_allow_unverified_ssl" {
  type        = bool
  description = "Skip TLS certificate verification for the vSphere provider. Set to false in production environments with a trusted certificate."
  default     = true
}

variable "gateway" {
  type        = string
  description = "Default gateway IP for static IP assignment (vSphere/bare metal)."
  default     = null
}

variable "netmask" {
  type        = number
  description = "Subnet mask prefix length (e.g. 24 for /24)."
  default     = null
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS server list for static IP assignment."
  default     = []
}

variable "jump_num_cpu" {
  type        = number
  description = "Number of vCPUs for the jump server VM (vSphere)."
  default     = 4
}

variable "jump_memory" {
  type        = number
  description = "Memory (MiB) for the jump server VM (vSphere)."
  default     = 8192
}

variable "nfs_num_cpu" {
  type        = number
  description = "Number of vCPUs for the NFS server VM (vSphere)."
  default     = 4
}

variable "nfs_memory" {
  type        = number
  description = "Memory (MiB) for the NFS server VM (vSphere)."
  default     = 16384
}

variable "cr_num_cpu" {
  type        = number
  description = "Number of vCPUs for the container registry VM (vSphere)."
  default     = 4
}

variable "cr_memory" {
  type        = number
  description = "Memory (MiB) for the container registry VM (vSphere)."
  default     = 8192
}

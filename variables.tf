# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Generic
#
variable "deployment_type" {
  type        = string
  description = "Options are: bare_metal, vsphere, or openstack"
  default     = "bare_metal"

  validation {
    condition     = contains(["bare_metal", "vsphere", "openstack"], var.deployment_type)
    error_message = "ERROR: Valid values for deployment_type are: bare_metal, vsphere, openstack"
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
# OpenStack
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
  description = "The name of the OpenStack Glance image to use for VMs (e.g. Ubuntu 22.04)."
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
    flavor       = null # OpenStack Nova flavor name; overrides openstack_flavor_defaults
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
  type        = string
  description = "Kubernetes version to install. Supported versions: 1.32.x, 1.33.x, 1.34.x"
  default     = "1.32.7"

  validation {
    condition     = can(regex("^1\\.(3[2-4])\\.", var.cluster_version))
    error_message = "ERROR: cluster_version must be a supported Kubernetes version: 1.32.x, 1.33.x, or 1.34.x"
  }
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

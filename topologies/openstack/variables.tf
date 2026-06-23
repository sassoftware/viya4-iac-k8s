# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Deployment Type
#
variable "deployment_type" {
  type        = string
  description = "Must be 'openstack' for this topology."
  default     = "openstack"

  validation {
    condition     = lower(var.deployment_type) == "openstack"
    error_message = "ERROR: deployment_type must be 'openstack' for the OpenStack topology."
  }
}

#
# OpenStack Provider
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

#
# Generic
#
variable "prefix" {
  description = "A prefix used in the name for all cloud resources created by this script. Must start with a lowercase letter and contain only lowercase alphanumeric characters or hyphens."
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

variable "iac_tooling" {
  description = "Value used to identify the tooling used to generate this provider's infrastructure"
  type        = string
  default     = "terraform"
}

variable "nat_ip" {
  type        = string
  description = "NAT IP"
  default     = null
}

#
# Kubernetes Cluster
#
variable "control_plane_ssh_key_name" {
  type    = string
  default = "cp_ssh"
}

variable "cluster_domain" {
  type    = string
  default = null
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version to install."
  default     = "1.34.6"

  validation {
    condition     = can(regex("^1\\.(3[2-5])\\.", var.cluster_version))
    error_message = "ERROR: cluster_version must be a supported Kubernetes version: 1.32.x, 1.33.x, 1.34.x, or 1.35.x"
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
  type        = string
  description = "Version of containerd to install. Must be >= 2.0.0 for KubeletCgroupDriverFromCRI auto-detection."
  default     = "2.2.2"
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
  description = "Map of kubernetes node defaults. 'flavor' overrides openstack_flavor_defaults for a specific pool."
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
  description = "Map of kubernetes node pools. Set 'flavor' per pool to override the default OpenStack flavor."
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

#
# Jump Server
#
variable "create_jump" {
  type    = bool
  default = false
}

variable "jump_ip" {
  type        = string
  description = "Pre-allocated IP for the jump server. Leave null for DHCP."
  default     = null
}

variable "jump_disk_size" {
  type    = number
  default = 100
}

#
# NFS Server
#
variable "create_nfs" {
  type    = bool
  default = false
}

variable "nfs_ip" {
  type        = string
  description = "Pre-allocated IP for the NFS server. Leave null for DHCP."
  default     = null
}

variable "nfs_disk_size" {
  type    = number
  default = 400
}

#
# Container Registry
#
variable "create_cr" {
  type    = bool
  default = false
}

variable "cr_ip" {
  type        = string
  description = "Pre-allocated IP for the container registry. Leave null for DHCP."
  default     = null
}

variable "cr_disk_size" {
  type    = number
  default = 160
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

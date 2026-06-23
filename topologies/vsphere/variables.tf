# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Deployment Type
#
variable "deployment_type" {
  type        = string
  description = "Must be 'vsphere' for this topology."
  default     = "vsphere"

  validation {
    condition     = lower(var.deployment_type) == "vsphere"
    error_message = "ERROR: deployment_type must be 'vsphere' for the vSphere topology."
  }
}

#
# vSphere Provider
#
variable "vsphere_server" {
  type        = string
  description = "Hostname or IP of the vSphere (vCenter) server."
  default     = null
}

variable "vsphere_user" {
  type        = string
  description = "vSphere user for authentication."
  default     = null
}

variable "vsphere_password" {
  type        = string
  description = "vSphere password for authentication."
  default     = null
  sensitive   = true
}

variable "vsphere_datacenter" {
  type        = string
  description = "Name of the vSphere data center."
  default     = null
}

variable "vsphere_datastore" {
  type        = string
  description = "Name of the vSphere data store to use for VMs."
  default     = null
}

variable "vsphere_resource_pool" {
  type        = string
  description = "Name of the vSphere resource pool to use for VMs."
  default     = null
}

variable "vsphere_folder" {
  type        = string
  description = "Name of the vSphere folder to store VMs."
  default     = null
}

variable "vsphere_template" {
  type        = string
  description = "Name of the VM template to clone."
  default     = null
}

variable "vsphere_network" {
  type        = string
  description = "Name of the network to attach VMs to."
  default     = null
}

variable "vsphere_allow_unverified_ssl" {
  type        = bool
  description = "Skip TLS certificate verification for the vSphere provider. Set to false in production environments with a trusted certificate."
  default     = true
}

#
# Network (static IPs)
#
variable "gateway" {
  type        = string
  description = "Default gateway IP for VMs."
  default     = ""
}

variable "netmask" {
  type        = number
  description = "Network interface netmask prefix length."
  default     = 16
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS server IP addresses."
  default     = ["10.19.1.24", "10.36.1.53"]
}

#
# Generic
#
variable "prefix" {
  description = "A prefix used in naming all resources. Must start with a lowercase letter and contain only lowercase alphanumeric characters or hyphens."
  type        = string
}

variable "ansible_user" {
  type    = string
  default = null
}

variable "ansible_password" {
  type      = string
  default   = null
  sensitive = true
}

variable "system_ssh_keys_dir" {
  type    = string
  default = "~/.ssh"
}

variable "inventory" {
  type        = string
  description = "File name and location of the generated inventory file."
  default     = "inventory"
}

variable "ansible_vars" {
  type        = string
  description = "File name and location of the generated ansible-vars.yaml file."
  default     = "ansible-vars.yaml"
}

variable "iac_tooling" {
  type    = string
  default = "terraform"
}

#
# VM / OS
#
variable "vm_os" {
  type        = string
  description = "OS type on VMs. Choices: ubuntu, rocky."
  default     = "ubuntu"

  validation {
    condition     = contains(["ubuntu", "rocky"], lower(var.vm_os))
    error_message = "ERROR: vm_os must be 'ubuntu' or 'rocky'."
  }
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
  type    = string
  default = "1.34.6"

  validation {
    condition     = can(regex("^1\\.(3[2-5])\\.", var.cluster_version))
    error_message = "ERROR: cluster_version must be 1.32.x – 1.35.x"
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
    error_message = "ERROR: cluster_lb_type must be kube_vip or metallb."
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
  description = "Default values merged into each node pool."
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
  description = "Map of kubernetes node pools."
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
    error_message = "ERROR: You must have at least one control_plane pool, one system pool, and one other pool."
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

#
# NFS Server
#
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

#
# Postgres
#
variable "postgres_server_defaults" {
  type = any
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
  type    = any
  default = null
  validation {
    condition     = var.postgres_servers == null || can([for pg in keys(var.postgres_servers) : regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", pg)])
    error_message = "ERROR: Postgres server names must be lowercase alphanumeric or '-', start and end with alphanumeric."
  }
}

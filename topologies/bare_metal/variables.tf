# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

#
# Deployment Type
#
variable "deployment_type" {
  type        = string
  description = "Must be 'bare_metal' for this topology."
  default     = "bare_metal"

  validation {
    condition     = lower(var.deployment_type) == "bare_metal"
    error_message = "ERROR: deployment_type must be 'bare_metal' for the bare metal topology."
  }
}

#
# Generic
#
variable "prefix" {
  description = "A prefix used in the name for all cluster resources. Must start with a lowercase letter and contain only lowercase alphanumeric characters or hyphens."
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

#
# VM / OS
#
variable "vm_os" {
  type        = string
  description = "Operating system type installed on bare metal nodes. Choices: ubuntu, rocky."
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
  type        = string
  description = "Kubernetes version to install."
  default     = "1.35.0"

  validation {
    condition     = can(regex("^1\\.(3[3-6])\\.", var.cluster_version))
    error_message = "ERROR: cluster_version must be a supported Kubernetes version: 1.33.x, 1.34.x, 1.35.x, or 1.36.x"
  }
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
# All IPs must be supplied via node_pools.ip_addresses — no cloud VMs are created.
#
variable "node_pool_defaults" {
  description = "Default values merged into each node pool entry."
  type        = any
  default = {
    count        = 0
    ip_addresses = []
    node_taints  = []
    node_labels  = {}
  }
}

variable "node_pools" {
  description = "Map of kubernetes node pools. Each pool must have ip_addresses set for bare metal."
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
  type        = string
  description = "IP address of the existing jump server."
  default     = null
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
  description = "IP address of the existing NFS server."
  default     = null
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
  description = "IP address of the existing container registry server."
  default     = null
}

#
# Postgres
#
variable "postgres_server_defaults" {
  description = "Default values merged into each postgres_servers entry."
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
  description = "Map of PostgreSQL server objects. Each entry must include server_ip for bare metal."
  type        = any
  default     = null
  validation {
    condition     = var.postgres_servers == null || can([for pg in keys(var.postgres_servers) : regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", pg)])
    error_message = "ERROR: Postgres server names must consist of lowercase alphanumeric characters or '-', and must start and end with an alphanumeric character."
  }
}

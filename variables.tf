#
# Generic
#
variable "deployment_type" {
  type        = string
  description = "Options are: bare_metal or vsphere"
  default     = "bare_metal"
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

variable "vsphere_cluster" {
  type        = string
  description = "This is the name of the vSphere cluster."
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
variable "control_plane_ips" {
  type    = list(any)
  default = []
}

variable "control_plane_count" {
  type    = number
  default = 0
}

variable "control_plane_memory" {
  type    = number
  default = 4096
}

variable "control_plane_num_cpu" {
  type    = number
  default = 2
}

variable "control_plane_disk_size" {
  type    = number
  default = 40
}

variable "control_plane_ssh_key_name" {
  type    = string
  default = "cp_ssh"
}

variable "node_ips" {
  type    = list(any)
  default = []
}

variable "node_count" {
  type    = number
  default = 0
}

variable "node_memory" {
  type    = number
  default = 4096
}

variable "node_num_cpu" {
  type    = number
  default = 2
}

variable "node_disk_size" {
  type    = number
  default = 40
}

# Node Pools
variable "node_pool_defaults" {
  description = "Map of kubernetes nodes defaults"
  type        = any
  default = {
    cpus         = 2
    memory       = 4096
    disk         = 25
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
  default = 8092
}

variable "nfs_num_cpu" {
  type    = number
  default = 4
}

variable "nfs_disk_size" {
  type    = number
  default = 250
}

# postgres
variable "postgres_server_defaults" {
  description = ""
  type        = any
  default = {
    server_num_cpu         = 8                       # 8 CPUs
    server_memory          = 16384                   # 16 GiB
    server_disk_size       = 250                     # 250 GiB
    server_ip              = ""                      # Assigned values for static IPs
    server_version         = 12                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
  }
}

variable "postgres_servers" {
  description = "Map of PostgreSQL server objects"
  type        = any
  default     = null
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
  type = string
}

variable "cluster_version" {
  type    = string
  default = null
}

variable "cluster_cni" {
  type    = string
  default = "calico"
}

variable "cluster_cri" {
  type    = string
  default = "containerd"
}

variable "cluster_service_subnet" {
  type    = string
  default = "10.43.0.0/16"
}

variable "cluster_pod_subnet" {
  type    = string
  default = "10.42.0.0/16"
}

variable "kube_vip_version" {
  type    = string
  default = "0.4.4"
}

variable "kube_vip_interface" {
  type    = string
  default = "ens160"
}

variable "kube_vip_ip" {
  type    = string
  default = null
}

variable "kube_vip_dns" {
  type    = string
  default = null
}

variable "kube_vip_range" {
  type    = string
  default = null
}

variable "iac_tooling" {
  description = "Value used to identify the tooling used to generate this provider's infrastructure"
  type        = string
  default     = "terraform"
}

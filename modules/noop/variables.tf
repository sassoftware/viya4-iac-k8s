variable "name" {
  type    = string
  default = null
}

variable "cluster_name" {
  type    = string
  default = null
}

variable "ip_addresses" {
  type    = list(string)
  default = []
}

variable "ip_address" {
  type    = string
  default = null
}

variable "instance_count" {
  type    = number
  default = 0
}

variable "datacenter_id" {
  type    = string
  default = null
}

variable "resource_pool_id" {
  type    = string
  default = null
}

variable "folder" {
  type    = string
  default = null
}

variable "datastore" {
  type    = string
  default = null
}

variable "network" {
  type    = string
  default = null
}

variable "template" {
  type    = string
  default = null
}

variable "cluster_domain" {
  type    = string
  default = null
}

variable "netmask" {
  type    = string
  default = null
}

variable "gateway" {
  type    = string
  default = null
}

variable "dns_servers" {
  type    = list(string)
  default = []
}

variable "num_cpu" {
  type    = number
  default = null
}

variable "memory" {
  type    = number
  default = null
}

variable "disk_size" {
  type    = number
  default = null
}

variable "misc_disks" {
  type    = list(number)
  default = []
}

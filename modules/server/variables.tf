variable "name" {
  type = string
}

variable "resource_pool_id" {
  type = string
}

variable "folder" {
  type = string
}

variable "datastore" {
  type = string
}

variable "network" {
  type = string
}

variable "cluster_domain" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "datacenter_id" {
  type = string
}

variable "template" {
  type = string
}

variable "ip_address" {
  type = string
}

variable "netmask" {
  type = string
}

variable "gateway" {
  type = string
}

variable "memory" {
  type = string
}

variable "num_cpu" {
  type = string
}

variable "disk_size" {
  type = string
}

variable "dns_servers" {
  type = list(any)
}

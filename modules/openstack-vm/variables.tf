# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name" {
  type        = string
  description = "Base name used when constructing instance hostnames."
}

variable "instance_count" {
  type        = number
  description = "Number of VM instances to create."
}

variable "image_name" {
  type        = string
  description = "Name of the OpenStack Glance image to use for the instances."
}

variable "flavor_name" {
  type        = string
  description = "OpenStack Nova flavor name that defines CPU/RAM for the instances."
}

variable "keypair_name" {
  type        = string
  description = "Name of the OpenStack Nova keypair to inject into the instances."
}

variable "security_groups" {
  type        = list(string)
  description = "List of OpenStack security group names to apply to each instance."
  default     = ["default"]
}

variable "network_name" {
  type        = string
  description = "Name of the OpenStack Neutron network to attach instances to."
}

variable "floating_ip_pool" {
  type        = string
  description = "Name of the external network used to allocate floating IPs. Set to null to disable floating IPs."
  default     = null
}

variable "availability_zone" {
  type        = string
  description = "OpenStack availability zone in which to create the instances."
  default     = "nova"
}

variable "cluster_name" {
  type        = string
  description = "Kubernetes cluster name used as a prefix in instance names."
}

variable "cluster_domain" {
  type        = string
  description = "DNS domain suffix for the cluster."
  default     = null
}

variable "ip_addresses" {
  type        = list(string)
  description = "List of static IP addresses to assign to instances. If empty, DHCP is used."
  default     = []
}

variable "os_disk_size" {
  type        = number
  description = "Root / OS volume size in GiB."
  default     = 25
}

variable "misc_disks" {
  type        = list(number)
  description = "Additional data volume sizes in GiB to attach to each instance."
  default     = []
}

variable "user_data" {
  type        = string
  description = "Cloud-init user-data to inject into instances. Defaults to creating an admin/admin local user with SSH password auth enabled."
  default     = null
}

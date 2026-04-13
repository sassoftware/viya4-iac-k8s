# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where resources will be created"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

#
# VNet Configuration
#
variable "vnet_name" {
  description = "Name of existing VNet. Leave null to create a new VNet"
  type        = string
  default     = null
}

variable "vnet_resource_group_name" {
  description = "Resource group name of existing VNet. Leave null to use main resource_group_name"
  type        = string
  default     = null
}

variable "vnet_address_space" {
  description = "Address space for the VNet (used only when creating new VNet)"
  type        = list(string)
}

variable "dns_servers" {
  description = "Custom DNS servers for VNet. Empty list uses Azure-provided DNS"
  type        = list(string)
  default     = []
}

#
# Subnet Configuration
#
variable "subnets" {
  description = "Map of subnets to create with their configuration"
  type = map(object({
    prefixes          = list(string)
    service_endpoints = list(string)
  }))
}

variable "existing_subnet_names" {
  description = "Map of existing subnet names to use instead of creating new subnets. Keys should match the subnet roles (k8s, misc, etc.)"
  type        = map(string)
  default     = {}
}

#
# NSG Configuration
#
variable "nsg_name" {
  description = "Name of existing NSG. Leave null to create a new NSG"
  type        = string
  default     = null
}

variable "create_nsg_rules" {
  description = "Whether to create Kubernetes-specific NSG rules. Set to false if using existing NSG with pre-configured rules"
  type        = bool
  default     = true
}

#
# NSG Rule CIDR Configuration
#
variable "ssh_source_cidrs" {
  description = "List of CIDRs allowed for SSH access (port 22) to VMs"
  type        = list(string)
}

variable "api_server_source_cidrs" {
  description = "List of CIDRs allowed for Kubernetes API server access (port 6443)"
  type        = list(string)
}

variable "nodeport_source_cidrs" {
  description = "List of CIDRs allowed for NodePort service access (ports 30000-32767). Leave empty to disable NodePort external access"
  type        = list(string)
  default     = []
}

#
# Tags
#
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

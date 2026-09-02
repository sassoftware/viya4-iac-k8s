// Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

variable "prefix" {
  description = "A prefix used for all resources created by this module."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where the load balancer will be created."
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed."
  type        = string
}

variable "control_plane_nic_ids" {
  description = "Map of control plane NIC IDs to associate with the load balancer backend pool. Key = node name, Value = NIC ID"
  type        = map(string)
}

variable "api_server_port" {
  description = "Kubernetes API server port"
  type        = number
  default     = 6443
}

variable "create_public_ip" {
  description = "Whether to create a public IP for the API LB (true = external access, false = internal only)"
  type        = bool
  default     = true
}

variable "create_internal_lb" {
  description = "Whether to create an internal LB for the API server endpoint (recommended for multi-control-plane)"
  type        = bool
  default     = true
}

variable "subnet_id" {
  description = "Subnet ID for the internal LB frontend (k8s subnet)"
  type        = string
}

variable "internal_lb_ip" {
  description = "Static private IP for the internal LB frontend. Must be within the subnet CIDR."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

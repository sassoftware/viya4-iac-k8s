# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# All common outputs delegate to local.active_module (defined in locals.tf).
# Topology-specific outputs (e.g. kubernetes_nodes_info is Azure-only) are
# guarded with try() so they degrade gracefully on other topologies.

output "deployment_type" {
  description = "Active deployment type."
  value       = local.deployment_type_normalized
}

output "cluster_name" {
  value = try(local.active_module.cluster_name, null)
}

output "prefix" {
  value = try(local.active_module.prefix, null)
}

output "provider_name" {
  value = try(local.active_module.provider_name, null)
}

output "location" {
  value = try(local.active_module.location, null)
}

output "jump_admin_username" {
  value = try(local.active_module.jump_admin_username, null)
}

output "nfs_admin_username" {
  value = try(local.active_module.nfs_admin_username, null)
}

output "postgres_servers" {
  value     = try(local.active_module.postgres_servers, null)
  sensitive = true
}

output "kube_api_endpoint" {
  description = "Public IP of the Azure Standard LB fronting the Kubernetes API server (Azure only)"
  value       = local.is_azure ? try(local.active_module.kube_api_endpoint, null) : null
}

output "kube_api_url" {
  description = "Full HTTPS URL of the Kubernetes API server (Azure only)"
  value       = local.is_azure ? try(local.active_module.kube_api_url, null) : null
}

output "node_pools_summary" {
  description = "Summary of configured node pools"
  value       = try(local.active_module.node_pools_summary, null)
}

output "node_selector_labels" {
  description = "Labels for pod nodeSelector usage"
  value       = try(local.active_module.node_selector_labels, null)
}

output "node_taints_by_pool" {
  description = "Taints applied to each node pool"
  value       = try(local.active_module.node_taints_by_pool, null)
}

output "kubernetes_nodes_info" {
  description = "Kubernetes node information for deployment automation (Azure only)"
  value       = local.is_azure ? try(local.active_module.kubernetes_nodes_info, null) : null
}


# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = local.cluster_name
}

output "prefix" {
  description = "Resource naming prefix"
  value       = var.prefix
}

output "provider_name" {
  description = "Cloud provider name"
  value       = "openstack"
}

output "location" {
  description = "OpenStack region where resources were deployed"
  value       = var.openstack_region
}

output "jump_admin_username" {
  description = "Admin username for the jump server"
  value       = var.ansible_user != null ? var.ansible_user : ""
}

output "jump_private_ip" {
  description = "Jump server IP address"
  value       = local.resolved_jump_ip
}

output "jump_public_ip" {
  description = "Jump server IP address (floating if enabled)"
  value       = local.resolved_jump_ip
}

output "nfs_admin_username" {
  description = "Admin username for the NFS server"
  value       = var.ansible_user != null ? var.ansible_user : ""
}

output "nfs_private_ip" {
  description = "NFS server IP address"
  value       = local.resolved_nfs_ip
}

output "nfs_public_ip" {
  description = "NFS server IP address (floating if enabled)"
  value       = local.resolved_nfs_ip
}

output "nat_ip" {
  description = "NAT IP"
  value       = var.nat_ip
}

output "control_plane_ips" {
  description = "IP addresses of Kubernetes control plane nodes"
  value       = local.control_plane_ips
}

output "node_ips" {
  description = "IP addresses of Kubernetes worker nodes"
  value       = local.node_ips
}

output "postgres_servers" {
  description = "PostgreSQL server connection details"
  value       = length(local.postgres_servers) != 0 ? local.postgres_outputs : null
  sensitive   = true
}

output "node_pools_summary" {
  description = "Summary of configured node pools"
  value = {
    for pool_name, pool_config in local.node_pools : pool_name => {
      count       = pool_config.count
      flavor      = lookup(pool_config, "flavor", var.openstack_flavor_defaults)
      os_disk     = pool_config.os_disk
      node_taints = pool_config.node_taints
      node_labels = pool_config.node_labels
    }
  }
}

output "node_selector_labels" {
  description = "Labels for pod nodeSelector usage"
  value = {
    for pool_name, pool_config in local.node_pools :
    pool_name => pool_config.node_labels
  }
}

output "node_taints_by_pool" {
  description = "Taints applied to each node pool"
  value = {
    for pool_name, pool_config in local.node_pools :
    pool_name => pool_config.node_taints
  }
}

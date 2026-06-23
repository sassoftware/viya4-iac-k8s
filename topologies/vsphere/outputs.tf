# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "cluster_name" {
  value = local.cluster_name
}

output "prefix" {
  value = var.prefix
}

output "provider_name" {
  value = "vsphere"
}

output "location" {
  value = var.vsphere_datacenter
}

output "jump_admin_username" {
  value = var.ansible_user != null ? var.ansible_user : ""
}

output "jump_private_ip" {
  value = local.resolved_jump_ip
}

output "jump_public_ip" {
  value = local.resolved_jump_ip
}

output "nfs_admin_username" {
  value = var.ansible_user != null ? var.ansible_user : ""
}

output "nfs_private_ip" {
  value = local.resolved_nfs_ip
}

output "nfs_public_ip" {
  value = local.resolved_nfs_ip
}

output "nat_ip" {
  value = null
}

output "control_plane_ips" {
  value = local.control_plane_ips
}

output "node_ips" {
  value = local.node_ips
}

output "postgres_servers" {
  value     = length(local.postgres_servers) != 0 ? local.postgres_outputs : null
  sensitive = true
}

output "node_pools_summary" {
  value = {
    for pool_name, pool_config in local.node_pools : pool_name => {
      count       = pool_config.count
      cpus        = pool_config.cpus
      memory      = pool_config.memory
      os_disk     = pool_config.os_disk
      node_taints = pool_config.node_taints
      node_labels = pool_config.node_labels
    }
  }
}

output "node_selector_labels" {
  value = {
    for pool_name, pool_config in local.node_pools :
    pool_name => pool_config.node_labels
  }
}

output "node_taints_by_pool" {
  value = {
    for pool_name, pool_config in local.node_pools :
    pool_name => pool_config.node_taints
  }
}

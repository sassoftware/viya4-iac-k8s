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
  value       = "azure"
}

output "location" {
  description = "Azure region where resources were deployed"
  value       = var.azure_location
}

output "jump_admin_username" {
  description = "Admin username for the jump server"
  value       = var.create_jump ? "jumpuser" : null
}

output "nfs_admin_username" {
  description = "Admin username for the NFS server"
  value       = var.create_nfs ? "nfsuser" : null
}

output "postgres_servers" {
  description = "PostgreSQL server connection details"
  value       = length(local.postgres_servers) != 0 ? local.postgres_outputs : null
  sensitive   = true
}

output "kube_api_endpoint" {
  description = "Public IP of the Azure Standard LB fronting the Kubernetes API server"
  value       = module.azure_api_lb.api_lb_public_ip
}

output "kube_api_url" {
  description = "Full HTTPS URL of the Kubernetes API server (for kubeconfig server field)"
  value       = module.azure_api_lb.api_lb_endpoint
}

output "node_pools_summary" {
  description = "Summary of configured node pools with taints, labels, and machine types"
  value = {
    for pool_name, pool_config in local.node_pools : pool_name => {
      count        = pool_config.count
      machine_type = lookup(pool_config, "machine_type", "N/A")
      os_disk      = pool_config.os_disk
      data_disks   = pool_config.data_disks
      node_taints  = pool_config.node_taints
      node_labels  = pool_config.node_labels
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

output "kubernetes_nodes_info" {
  description = "Kubernetes node information for deployment automation"
  value = {
    for pool_name, pool_config in local.node_pools : pool_name => {
      count        = length([for key, vm in module.azure_vms : vm if startswith(key, "${pool_name}-")])
      node_type    = pool_name == "control_plane" ? "control-plane" : pool_name
      labels       = pool_config.node_labels
      taints       = pool_config.node_taints
      machine_type = lookup(pool_config, "machine_type", "")
    }
  }
}

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "cluster_name" {
  value = local.cluster_name
}

output "jump_admin_username" {
  value = "root"
}

# output "jump_private_ip" {
#   value = var.create_jump ? element(module.jump.ip_addresses, 0) : null
# }

# output "jump_public_ip" {
#   value = var.create_jump ? element(module.jump.ip_addresses, 0) : null
# }

# TODO: Fix this must be a variable
output "jump_rwx_filestore_path" {
  value = "/viya-share"
}

output "location" {
  value = "local"
}

output "nat_ip" {
  value = var.nat_ip
}

output "nfs_admin_username" {
  value = "root"
}

# output "nfs_private_ip" {
#   value = var.create_nfs ? element(module.nfs.ip_addresses, 0) : null
# }

# output "nfs_public_ip" {
#   value = var.create_nfs ? element(module.nfs.ip_addresses, 0) : null
# }

output "prefix" {
  value = var.prefix
}

output "provider" {
  value = "oss"
}

output "provder_account" {
  value = "oss"
}

# output "rwx_filestore_endpoint" {
#   value = var.create_nfs ? element(module.nfs.ip_addresses, 0) : null
# }

# TODO: Fix this must be a variable
output "rwx_filestore_path" {
  value = "/export"
}

output "postgres_servers" {
  value     = length(local.postgres_servers) != 0 ? local.postgres_outputs : null
  sensitive = true
}

# ==========================================
# PSCLOUD-771: Worker Node Configuration Outputs
# ==========================================

output "node_pools_summary" {
  description = "Summary of configured node pools with taints, labels, and machine types"
  value = var.deployment_type == "azure" ? {
    for pool_name, pool_config in local.node_pools : pool_name => {
      count        = pool_config.count
      machine_type = lookup(pool_config, "machine_type", "N/A")
      os_disk      = pool_config.os_disk
      data_disks   = pool_config.data_disks
      node_taints  = pool_config.node_taints
      node_labels  = pool_config.node_labels
    }
  } : null
}

output "node_selector_labels" {
  description = "Labels for pod nodeSelector usage (for scheduling workloads to specific node pools)"
  value = var.deployment_type == "azure" ? {
    for pool_name, pool_config in local.node_pools :
    pool_name => pool_config.node_labels
  } : null
}

output "node_taints_by_pool" {
  description = "Taints applied to each node pool (for pod toleration configuration)"
  value = var.deployment_type == "azure" ? {
    for pool_name, pool_config in local.node_pools :
    pool_name => pool_config.node_taints
  } : null
}

output "kubernetes_nodes_info" {
  description = "Kubernetes node information for deployment automation (PSCLOUD-772)"
  value = var.deployment_type == "azure" ? {
    control_plane = {
      count        = length([for key, vm in module.azure_vms : vm if startswith(key, "control_plane-")])
      node_type    = "control-plane"
      labels       = try(local.node_pools.control_plane.node_labels, {})
      taints       = try(local.node_pools.control_plane.node_taints, [])
      machine_type = try(local.node_pools.control_plane.machine_type, "")
    }
    system = {
      count        = length([for key, vm in module.azure_vms : vm if startswith(key, "system-")])
      node_type    = "system"
      labels       = try(local.node_pools.system.node_labels, {})
      taints       = try(local.node_pools.system.node_taints, [])
      machine_type = try(local.node_pools.system.machine_type, "")
    }
    cas = {
      count        = length([for key, vm in module.azure_vms : vm if startswith(key, "cas-")])
      node_type    = "cas"
      labels       = try(local.node_pools.cas.node_labels, {})
      taints       = try(local.node_pools.cas.node_taints, [])
      machine_type = try(local.node_pools.cas.machine_type, "")
    }
    generic = {
      count        = length([for key, vm in module.azure_vms : vm if startswith(key, "generic-")])
      node_type    = "worker"
      labels       = try(local.node_pools.generic.node_labels, {})
      taints       = try(local.node_pools.generic.node_taints, [])
      machine_type = try(local.node_pools.generic.machine_type, "")
    }
  } : null
}

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  topology_type = var.deployment_type

  # Kubernetes cluster name
  cluster_name = "${var.prefix}-oss"

  # Calculate DNS IP as the 10th IP in the service subnet
  cluster_dns_ip = cidrhost(var.cluster_service_subnet, 10)

  # Node pools (merged with defaults)
  node_pools               = var.node_pools == null ? {} : { for k, v in var.node_pools : k => merge(var.node_pool_defaults, v) }
  control_plane_node_count = try(local.node_pools["control_plane"].count, 0)
  node_labels              = var.node_pools == null ? {} : { for k, v in local.node_pools : k => [for lk, lv in v.node_labels : "${lk}=${lv}"] }
  node_taints              = var.node_pools == null ? {} : { for k, v in local.node_pools : k => v.node_taints }

  # Load balancer addresses
  loadbalancer_addresses = var.cluster_lb_addresses != null ? length(var.cluster_lb_addresses) > 0 ? [for v in var.cluster_lb_addresses : v] : null : null

  # PostgreSQL servers (merged with defaults)
  postgres_servers = var.postgres_servers == null ? {} : { for k, v in var.postgres_servers : k => merge(var.postgres_server_defaults, v) }

  postgres_outputs = length(local.postgres_servers) != 0 ? { for k, v in local.postgres_servers :
    k => {
      "server_name" : "${local.cluster_name}-${k}-pgsql",
      "fqdn" : "${local.cluster_name}-${k}-pgsql.${var.cluster_domain}",
      "admin" : v.administrator_login,
      "password" : v.administrator_password,
      "server_port" : "5432",
      "ssl_enforcement_enabled" : v.server_ssl == "off" ? false : true,
      "internal" : false
    }
  } : {}

  # Azure node pool configuration from node_pools variable
  azure_node_pools = {
    for k, v in local.node_pools : k => {
      pool_name    = k
      count        = v.count
      machine_type = lookup(v, "machine_type", "Standard_D4s_v5")
      os_disk      = lookup(v, "os_disk", 100)
      data_disks   = lookup(v, "data_disks", [])
      node_taints  = lookup(v, "node_taints", [])
      node_labels  = lookup(v, "node_labels", {})
    }
  }

  # Per-pool VM map
  azure_vms = {
    for pool_name, pool_config in local.azure_node_pools :
    pool_name => {
      for i in range(pool_config.count) :
      "${pool_name}-${i + 1}" => {
        vm_name      = "${local.cluster_name}-${pool_name}-${i + 1}"
        machine_type = pool_config.machine_type
        os_disk      = pool_config.os_disk
        data_disks   = pool_config.data_disks
        node_taints  = pool_config.node_taints
        node_labels  = pool_config.node_labels
      }
    }
  }

  # Flat map for for_each
  azure_vms_flat = {
    for item in flatten([
      for pool_name, vms in local.azure_vms : [
        for vm_key, vm_config in vms : {
          key       = "${pool_name}-${vm_key}"
          pool_name = pool_name
          vm_key    = vm_key
          config    = vm_config
        }
      ]
      ]) : item.key => merge(item.config, {
      pool_name = item.pool_name
      vm_key    = item.vm_key
    })
  }

  # IP extraction from Azure VM modules
  azure_control_plane_ips = [
    for key, vm in module.azure_vms : vm.private_ip_address if startswith(key, "control_plane-")
  ]

  # Single CP uses the first control plane private IP to avoid Azure ILB hairpin constraints.
  # Multi-CP uses the internal LB frontend IP for HA.
  kubernetes_control_plane_endpoint_ip = local.control_plane_node_count > 1 ? var.cluster_api_internal_ip : try(local.azure_control_plane_ips[0], null)

  azure_node_ips = [
    for key, vm in module.azure_vms : vm.private_ip_address if !startswith(key, "control_plane-")
  ]

  azure_jump_ip        = var.create_jump ? module.azure_jump[0].private_ip_address : null
  azure_jump_public_ip = var.create_jump ? module.azure_jump[0].public_ip_address : null
  azure_nfs_ip         = var.create_nfs ? module.azure_nfs[0].private_ip_address : null
}
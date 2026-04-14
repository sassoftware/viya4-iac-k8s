# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {

  # Systems

  # Kubernetes
  cluster_name = "${var.prefix}-oss"

  # Calculate DNS IP as the 10th IP in the service subnet
  cluster_dns_ip = cidrhost(var.cluster_service_subnet, 10)

  ## User defined node_pools
  node_pools  = var.node_pools == null ? {} : { for k, v in var.node_pools : k => merge(var.node_pool_defaults, v, ) }
  node_labels = var.node_pools == null ? {} : { for k, v in local.node_pools : k => [for lk, lv in v.node_labels : "${lk}=${lv}"] }
  node_taints = var.node_pools == null ? {} : { for k, v in local.node_pools : k => v.node_taints }

  ## Control plane nodes
  control_plane_nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "control_plane" }
  control_plane_ips   = flatten(sort(flatten([for item in values(module.control_plane) : values(item)])))

  ## System nodes
  system_nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "system" }
  # system_node_ips = flatten(sort(flatten([for item in values(module.system) : values(item)]))) not used, ref for future use

  ## Nodes
  nodes    = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if(k != "control_plane" && k != "system") }
  node_ips = flatten(sort(flatten([for item in values(merge(module.system, module.node)) : values(item)])))

  ## Load Balancer addresses and data items for kube-vip and MetalLB
  loadbalancer_addresses = var.cluster_lb_addresses != null ? length(var.cluster_lb_addresses) > 0 ? [for v in var.cluster_lb_addresses : v] : null : null

  # PostgreSQL
  postgres_servers = var.postgres_servers == null ? {} : { for k, v in var.postgres_servers : k => merge(var.postgres_server_defaults, v, ) }

  postgres_outputs = length(local.postgres_servers) != 0 ? { for k, v in local.postgres_servers :
    k => {
      "server_name" : "${local.cluster_name}-${k}-pgsql",
      "fqdn" : "${local.cluster_name}-${k}-pgsql.${var.cluster_domain}",
      "admin" : v.administrator_login,
      "password" : v.administrator_password,
      "server_port" : "5432",
      "ssl_enforcement_enabled" : v.server_ssl == "off" ? false : true
      "internal" : false
    }
  } : {}

  # Azure-specific node pool configuration
  # Filters node_pools for Azure deployment and creates numbered VM names
  azure_node_pools = var.deployment_type == "azure" ? {
    for k, v in local.node_pools : k => {
      pool_name    = k
      count        = v.count
      machine_type = lookup(v, "machine_type", "Standard_D4s_v5")
      os_disk      = lookup(v, "os_disk", 100)
      data_disks   = lookup(v, "data_disks", [])
      node_taints  = lookup(v, "node_taints", [])
      node_labels  = lookup(v, "node_labels", {})
    }
  } : {}

  # Create a flat list of Azure VMs for module instantiation
  # Maps pool names to VM instances with sequential numbering
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

  # Flatten Azure VMs for easier module instantiation
  azure_vms_flat = flatten([
    for pool_name, vms in local.azure_vms : [
      for vm_key, vm_config in vms : merge(vm_config, {
        pool_name = pool_name
        vm_key    = vm_key
      })
    ]
  ])

  # ==========================================
  # PSCLOUD-785: Azure IP Extraction
  # ==========================================

  # Extract IPs from consolidated azure_vms module
  azure_control_plane_ips = var.deployment_type == "azure" ? [
    for vm in module.azure_vms : vm.private_ip_address if vm.pool_name == "control_plane"
  ] : []

  azure_node_ips = var.deployment_type == "azure" ? [
    for vm in module.azure_vms : vm.private_ip_address if contains(["system", "cas", "generic"], vm.pool_name)
  ] : []

  azure_jump_ip = var.deployment_type == "azure" && var.create_jump ? module.azure_jump[0].private_ip_address : null

  azure_nfs_ip = var.deployment_type == "azure" && var.create_nfs ? module.azure_nfs[0].private_ip_address : null

  # Select appropriate IPs based on deployment type
  final_control_plane_ips = var.deployment_type == "azure" ? local.azure_control_plane_ips : local.control_plane_ips
  final_node_ips          = var.deployment_type == "azure" ? local.azure_node_ips : local.node_ips
  final_jump_ip           = var.deployment_type == "azure" ? local.azure_jump_ip : (var.create_jump ? var.jump_ip : null)
  final_nfs_ip            = var.deployment_type == "azure" ? local.azure_nfs_ip : (var.create_nfs ? var.nfs_ip : null)

}

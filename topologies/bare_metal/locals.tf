# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {

  # Kubernetes cluster name
  cluster_name = "${var.prefix}-oss"

  # Calculate DNS IP as the 10th IP in the service subnet
  cluster_dns_ip = cidrhost(var.cluster_service_subnet, 10)

  # Node pool handling (merge defaults then split by type)
  node_pools  = var.node_pools == null ? {} : { for k, v in var.node_pools : k => merge(var.node_pool_defaults, v) }
  node_labels = var.node_pools == null ? {} : { for k, v in local.node_pools : k => [for lk, lv in v.node_labels : "${lk}=${lv}"] }
  node_taints = var.node_pools == null ? {} : { for k, v in local.node_pools : k => v.node_taints }

  control_plane_nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "control_plane" }
  system_nodes        = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "system" }
  nodes               = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if(k != "control_plane" && k != "system") }

  # For bare metal all IPs come from node_pools.ip_addresses — no VM modules exist.
  control_plane_ips = sort(flatten([
    for v in values(local.control_plane_nodes) : lookup(v, "ip_addresses", [])
  ]))

  node_ips = sort(flatten([
    for v in values(merge(local.system_nodes, local.nodes)) : lookup(v, "ip_addresses", [])
  ]))

  # Auxiliary server IPs (pre-existing machines)
  resolved_jump_ip = var.create_jump ? var.jump_ip : null
  resolved_nfs_ip  = var.create_nfs ? var.nfs_ip : null
  resolved_cr_ip   = var.create_cr ? var.cr_ip : null

  # Load balancer address list
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
      "ssl_enforcement_enabled" : v.server_ssl == "off" ? false : true
      "internal" : false
    }
  } : {}

}

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {

  # Kubernetes cluster name
  cluster_name = "${var.prefix}-oss"

  # Derive Ansible OS type from image name (contains 'ubuntu' → ubuntu, else → rocky)
  vm_os = can(regex("(?i)ubuntu", var.openstack_image_name)) ? "ubuntu" : "rocky"

  # Calculate DNS IP as the 10th IP in the service subnet
  cluster_dns_ip = cidrhost(var.cluster_service_subnet, 10)

  # Node pools (merged with defaults)
  node_pools  = var.node_pools == null ? {} : { for k, v in var.node_pools : k => merge(var.node_pool_defaults, v) }
  node_labels = var.node_pools == null ? {} : { for k, v in local.node_pools : k => [for lk, lv in v.node_labels : "${lk}=${lv}"] }
  node_taints = var.node_pools == null ? {} : { for k, v in local.node_pools : k => v.node_taints }

  # Node pool splits
  control_plane_nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "control_plane" }
  system_nodes        = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "system" }
  nodes               = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if(k != "control_plane" && k != "system") }

  # IP extraction from OpenStack VM modules
  control_plane_ips = flatten(sort(flatten([for item in values(module.os_control_plane) : item.ip_addresses])))
  node_ips          = flatten(sort(flatten([for item in values(merge(module.os_system, module.os_node)) : item.ip_addresses])))

  # Auxiliary server IPs
  resolved_jump_ip = var.create_jump ? (
    length(try(module.os_jump.ip_addresses, [])) > 0 ? try(module.os_jump.ip_addresses[0], null) : null
  ) : null

  resolved_nfs_ip = var.create_nfs ? (
    length(try(module.os_nfs.ip_addresses, [])) > 0 ? try(module.os_nfs.ip_addresses[0], null) : null
  ) : null

  resolved_cr_ip = var.create_cr ? (
    length(try(module.os_cr.ip_addresses, [])) > 0 ? try(module.os_cr.ip_addresses[0], null) : null
  ) : null

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
      "ssl_enforcement_enabled" : v.server_ssl == "off" ? false : true
      "internal" : false
    }
  } : {}

}

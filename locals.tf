# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {

  # Systems

  # Kubernetes
  cluster_name = "${var.prefix}-oss"

  # Derive Ansible OS type from image name (contains 'ubuntu' → ubuntu, else → rocky)
  vm_os = can(regex("(?i)ubuntu", var.openstack_image_name)) ? "ubuntu" : "rocky"
  
  # Calculate DNS IP as the 10th IP in the service subnet
  cluster_dns_ip = cidrhost(var.cluster_service_subnet, 10)

  ## User defined node_pools
  node_pools  = var.node_pools == null ? {} : { for k, v in var.node_pools : k => merge(var.node_pool_defaults, v, ) }
  node_labels = var.node_pools == null ? {} : { for k, v in local.node_pools : k => [for lk, lv in v.node_labels : "${lk}=${lv}"] }
  node_taints = var.node_pools == null ? {} : { for k, v in local.node_pools : k => v.node_taints }

  ## Control plane nodes
  control_plane_nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "control_plane" }

  # IPs for control-plane nodes – prefer OpenStack output when deployment_type=openstack
  control_plane_ips = var.deployment_type == "openstack" ? (
    flatten(sort(flatten([for item in values(try(module.os_control_plane, {})) : item.ip_addresses])))
  ) : (
    flatten(sort(flatten([for item in values(try(module.control_plane, {})) : values(item)])))
  )

  ## System nodes
  system_nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "system" }

  ## Nodes (all non-control-plane, non-system pools)
  nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if(k != "control_plane" && k != "system") }

  # Worker node IPs – prefer OpenStack output when deployment_type=openstack
  node_ips = var.deployment_type == "openstack" ? (
    flatten(sort(flatten([for item in values(merge(try(module.os_system, {}), try(module.os_node, {}))) : item.ip_addresses])))
  ) : (
    flatten(sort(flatten([for item in values(merge(try(module.system, {}), try(module.node, {}))) : values(item)])))
  )

  ## Load Balancer addresses and data items for kube-vip and MetalLB
  loadbalancer_addresses = var.cluster_lb_addresses != null ? length(var.cluster_lb_addresses) > 0 ? [for v in var.cluster_lb_addresses : v] : null : null

  # ---------------------------------------------------------------------------
  # Resolved auxiliary server IPs – works for vsphere, openstack, and bare_metal
  # ---------------------------------------------------------------------------

  resolved_jump_ip = (
    var.deployment_type == "openstack" && var.create_jump ? (
      length(try(module.os_jump.ip_addresses, [])) > 0 ? try(module.os_jump.ip_addresses[0], null) : null
    ) : (
      var.create_jump ? var.jump_ip : null
    )
  )

  resolved_nfs_ip = (
    var.deployment_type == "openstack" && var.create_nfs ? (
      length(try(module.os_nfs.ip_addresses, [])) > 0 ? try(module.os_nfs.ip_addresses[0], null) : null
    ) : (
      var.create_nfs ? var.nfs_ip : null
    )
  )

  resolved_cr_ip = (
    var.deployment_type == "openstack" && var.create_cr ? (
      length(try(module.os_cr.ip_addresses, [])) > 0 ? try(module.os_cr.ip_addresses[0], null) : null
    ) : (
      var.create_cr ? var.cr_ip : null
    )
  )

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

}

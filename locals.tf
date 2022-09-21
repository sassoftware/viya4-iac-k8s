locals {

  # Systems

  # Kubernetes
  cluster_name = "${var.prefix}-oss"

  ## User defined node_pools
  node_pools  = var.node_pools == null ? {} : { for k, v in var.node_pools : k => merge(var.node_pool_defaults, v, ) }
  node_labels = var.node_pools == null ? {} : { for k, v in local.node_pools : k => [for lk, lv in v.node_labels : "${lk}=${lv}"] }
  node_taints = var.node_pools == null ? {} : { for k, v in local.node_pools : k => v.node_taints }

  ## Control plane nodes
  control_plane_nodes = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "control_plane" }
  control_plane_ips   = flatten(sort(flatten([for item in values(module.control_plane) : values(item)])))

  ## System nodes
  system_nodes    = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if k == "system" }
  system_node_ips = flatten(sort(flatten([for item in values(module.system) : values(item)])))

  ## Nodes
  nodes    = local.node_pools == null ? {} : { for k, v in local.node_pools : k => v if(k != "control_plane" && k != "system") }
  node_ips = flatten(sort(flatten([for item in values(merge(module.system, module.node)) : values(item)])))

  ## Load Balancer addresses and data items for kube-vip and metallb
  cluster_lb_addresses = var.kube_lb_addresses != null ? length(var.kube_lb_addresses) > 0 ? [for v in var.kube_lb_addresses : v] : null : null

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

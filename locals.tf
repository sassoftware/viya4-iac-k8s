locals {

  # Systems
  control_plane_count = length(var.control_plane_ips) > 0 ? length(var.control_plane_ips) : var.control_plane_count
  node_count          = length(var.node_ips) > 0 ? length(var.node_ips) : var.node_count

  # Kubernetes
  cluster_name = "${var.prefix}-oss"

  # PostgreSQL
  #
  # TODO: Align with actual cloud providers to take user input
  #       to create n number of database servers at the infrastructure
  #       level for use.
  #

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

locals {
  resolved_ip_addresses = length(var.ip_addresses) > 0 ? var.ip_addresses : (var.ip_address != null ? [var.ip_address] : [])
}

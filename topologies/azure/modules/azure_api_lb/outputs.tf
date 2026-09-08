# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "api_lb_id" {
  description = "Azure resource ID of the public API server load balancer"
  value       = var.create_public_ip ? azurerm_lb.api[0].id : null
}

output "api_lb_internal_id" {
  description = "Azure resource ID of the internal API server load balancer"
  value       = var.create_internal_lb ? azurerm_lb.api_internal[0].id : null
}

output "api_lb_public_ip" {
  description = "Public IP address of the API server load balancer"
  value       = var.create_public_ip ? azurerm_public_ip.api_lb[0].ip_address : null
}

output "api_lb_frontend_ip" {
  description = "Frontend IP of the load balancer (public or private)"
  value       = var.create_public_ip ? azurerm_public_ip.api_lb[0].ip_address : var.internal_lb_ip
}

output "api_lb_endpoint" {
  description = "Full HTTPS endpoint for the Kubernetes API server"
  value       = var.create_public_ip ? "https://${azurerm_public_ip.api_lb[0].ip_address}:${var.api_server_port}" : null
}

output "api_lb_internal_ip" {
  description = "Private IP of the internal LB frontend (used as controlPlaneEndpoint)"
  value       = var.create_internal_lb ? var.internal_lb_ip : null
}

output "backend_pool_id" {
  description = "Backend address pool ID for the public LB (adding additional control plane nodes)"
  value       = var.create_public_ip ? azurerm_lb_backend_address_pool.api[0].id : null
}

output "backend_pool_internal_id" {
  description = "Backend address pool ID for the internal LB"
  value       = var.create_internal_lb ? azurerm_lb_backend_address_pool.api_internal[0].id : null
}

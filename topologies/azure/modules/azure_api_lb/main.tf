# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# ==========================================
# Public IP for Kubernetes API Server LB
# ==========================================

resource "azurerm_public_ip" "api_lb" {
  count               = var.create_public_ip ? 1 : 0
  name                = "${var.prefix}-k8s-api-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ==========================================
# Public Load Balancer for external kubectl access
# ==========================================

resource "azurerm_lb" "api" {
  count               = var.create_public_ip ? 1 : 0
  name                = "${var.prefix}-k8s-api-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "ApiServerFrontend"
    public_ip_address_id = azurerm_public_ip.api_lb[0].id
  }
}

# ==========================================
# Internal Load Balancer for in-cluster HA
# (Azure LBs cannot mix public + internal frontends)
# ==========================================

resource "azurerm_lb" "api_internal" {
  name                = "${var.prefix}-k8s-api-internal-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = "ApiServerInternalFrontend"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.internal_lb_ip
  }
}

# ==========================================
# Backend Pool - Public LB
# ==========================================

resource "azurerm_lb_backend_address_pool" "api" {
  count           = var.create_public_ip ? 1 : 0
  loadbalancer_id = azurerm_lb.api[0].id
  name            = "control-plane-pool"
}

# ==========================================
# Backend Pool - Internal LB
# ==========================================

resource "azurerm_lb_backend_address_pool" "api_internal" {
  loadbalancer_id = azurerm_lb.api_internal.id
  name            = "control-plane-pool-internal"
}

# ==========================================
# Health Probe - Public LB
# ==========================================

resource "azurerm_lb_probe" "api" {
  count               = var.create_public_ip ? 1 : 0
  loadbalancer_id     = azurerm_lb.api[0].id
  name                = "api-server-probe"
  protocol            = "Tcp"
  port                = var.api_server_port
  interval_in_seconds = 5
  number_of_probes    = 2
}

# ==========================================
# Health Probe - Internal LB
# ==========================================

resource "azurerm_lb_probe" "api_internal" {
  loadbalancer_id     = azurerm_lb.api_internal.id
  name                = "api-server-probe-internal"
  protocol            = "Tcp"
  port                = var.api_server_port
  interval_in_seconds = 5
  number_of_probes    = 2
}

# ==========================================
# Load Balancing Rule - Public LB
# ==========================================

resource "azurerm_lb_rule" "api" {
  count                          = var.create_public_ip ? 1 : 0
  loadbalancer_id                = azurerm_lb.api[0].id
  name                           = "api-server-rule"
  protocol                       = "Tcp"
  frontend_port                  = var.api_server_port
  backend_port                   = var.api_server_port
  frontend_ip_configuration_name = "ApiServerFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.api[0].id]
  probe_id                       = azurerm_lb_probe.api[0].id
  floating_ip_enabled            = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
}

# ==========================================
# Load Balancing Rule - Internal LB
# ==========================================

resource "azurerm_lb_rule" "api_internal" {
  loadbalancer_id                = azurerm_lb.api_internal.id
  name                           = "api-server-rule-internal"
  protocol                       = "Tcp"
  frontend_port                  = var.api_server_port
  backend_port                   = var.api_server_port
  frontend_ip_configuration_name = "ApiServerInternalFrontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.api_internal.id]
  probe_id                       = azurerm_lb_probe.api_internal.id
  floating_ip_enabled            = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
}

# ==========================================
# Associate Control Plane NICs with Public LB Backend Pool
# ==========================================

resource "azurerm_network_interface_backend_address_pool_association" "control_plane" {
  for_each = var.create_public_ip ? var.control_plane_nic_ids : {}

  network_interface_id    = each.value
  ip_configuration_name   = "testConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.api[0].id
}

# ==========================================
# Associate Control Plane NICs with Internal LB Backend Pool
# ==========================================

resource "azurerm_network_interface_backend_address_pool_association" "control_plane_internal" {
  for_each = var.control_plane_nic_ids

  network_interface_id    = each.value
  ip_configuration_name   = "testConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.api_internal.id
}

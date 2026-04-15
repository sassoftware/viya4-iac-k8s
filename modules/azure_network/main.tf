# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Azure Virtual Network Module for Kubernetes
# Creates VNet, Subnets, NSG with Kubernetes-specific rules

locals {
  vnet_name     = var.vnet_name != null ? var.vnet_name : "${var.prefix}-vnet"
  nsg_name      = var.nsg_name != null ? var.nsg_name : "${var.prefix}-k8s-nsg"
  misc_nsg_name = var.misc_nsg_name != null ? var.misc_nsg_name : "${var.prefix}-misc-nsg"

  # Determine VNet resource group - use vnet RG if specified, otherwise main RG
  vnet_rg_name = var.vnet_resource_group_name != null ? var.vnet_resource_group_name : var.resource_group_name

  # Build subnet map - either from existing or newly created
  subnets = length(var.existing_subnet_names) == 0 ? {
    for k, v in azurerm_subnet.subnet : k => {
      id               = v.id
      name             = v.name
      address_prefixes = v.address_prefixes
    }
    } : {
    for k, v in data.azurerm_subnet.existing : k => {
      id               = v.id
      name             = v.name
      address_prefixes = v.address_prefixes
    }
  }
}

# Data source for existing VNet
data "azurerm_virtual_network" "existing" {
  count               = var.vnet_name != null ? 1 : 0
  name                = local.vnet_name
  resource_group_name = local.vnet_rg_name
}

# Create new VNet
resource "azurerm_virtual_network" "vnet" {
  count               = var.vnet_name == null ? 1 : 0
  name                = local.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers
  tags                = var.tags
}

# Data source for existing subnets
data "azurerm_subnet" "existing" {
  for_each             = length(var.existing_subnet_names) == 0 ? {} : var.existing_subnet_names
  name                 = each.value
  virtual_network_name = local.vnet_name
  resource_group_name  = local.vnet_rg_name

  depends_on = [
    data.azurerm_virtual_network.existing,
    azurerm_virtual_network.vnet
  ]
}

# Create new subnets
resource "azurerm_subnet" "subnet" {
  for_each             = length(var.existing_subnet_names) == 0 ? var.subnets : {}
  name                 = "${var.prefix}-${each.key}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = local.vnet_name
  address_prefixes     = each.value.prefixes
  service_endpoints    = each.value.service_endpoints

  depends_on = [
    data.azurerm_virtual_network.existing,
    azurerm_virtual_network.vnet
  ]
}

# Data source for existing NSG
data "azurerm_network_security_group" "existing" {
  count               = var.nsg_name != null ? 1 : 0
  name                = local.nsg_name
  resource_group_name = var.resource_group_name
}

# Create new k8s NSG
resource "azurerm_network_security_group" "nsg" {
  count               = var.nsg_name == null ? 1 : 0
  name                = local.nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Data source for existing misc NSG (jump/nfs subnet)
data "azurerm_network_security_group" "existing_misc" {
  count               = var.misc_nsg_name != null ? 1 : 0
  name                = local.misc_nsg_name
  resource_group_name = var.resource_group_name
}

# Create new misc NSG (jump/nfs subnet)
resource "azurerm_network_security_group" "nsg_misc" {
  count               = var.misc_nsg_name == null ? 1 : 0
  name                = local.misc_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# NSG Rules for Kubernetes

# Rule 1a: SSH Access (Port 22) on misc NSG - external CIDRs reach jump server
resource "azurerm_network_security_rule" "ssh_misc" {
  count                       = var.create_nsg_rules && length(var.ssh_source_cidrs) > 0 ? 1 : 0
  name                        = "AllowSSH"
  description                 = "Allow SSH access to jump/nfs VMs from external CIDRs"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.ssh_source_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.misc_nsg_name

  depends_on = [
    azurerm_network_security_group.nsg_misc,
    data.azurerm_network_security_group.existing_misc
  ]
}

# Rule 1b: SSH Access (Port 22) on k8s NSG - only from within VNet (jump server)
resource "azurerm_network_security_rule" "ssh_k8s" {
  count                       = var.create_nsg_rules ? 1 : 0
  name                        = "AllowSSHFromVNet"
  description                 = "Allow SSH to k8s nodes from within VNet (jump server only)"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Rule 2: Kubernetes API Server (Port 6443)
resource "azurerm_network_security_rule" "k8s_api" {
  count                       = var.create_nsg_rules && length(var.api_server_source_cidrs) > 0 ? 1 : 0
  name                        = "AllowKubernetesAPI"
  description                 = "Allow Kubernetes API server access"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "6443"
  source_address_prefixes     = var.api_server_source_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Rule 3: Kubelet API (Port 10250) - Internal only
resource "azurerm_network_security_rule" "kubelet" {
  count                       = var.create_nsg_rules ? 1 : 0
  name                        = "AllowKubeletAPI"
  description                 = "Allow Kubelet API - internal VNet only"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "10250"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Rule 4: kube-proxy health checks (Port 10256) - Internal only
resource "azurerm_network_security_rule" "kube_proxy" {
  count                       = var.create_nsg_rules ? 1 : 0
  name                        = "AllowKubeProxyHealth"
  description                 = "Allow kube-proxy health checks - internal VNet only"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "10256"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Rule 5: Calico Typha (Port 5473) - Internal only
resource "azurerm_network_security_rule" "calico_typha" {
  count                       = var.create_nsg_rules ? 1 : 0
  name                        = "AllowCalicoTypha"
  description                 = "Allow Calico Typha for CNI - internal VNet only"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5473"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Rule 6: BGP for Calico (Port 179) - Internal only
resource "azurerm_network_security_rule" "bgp" {
  count                       = var.create_nsg_rules ? 1 : 0
  name                        = "AllowBGP"
  description                 = "Allow BGP for Calico routing - internal VNet only"
  priority                    = 150
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "179"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Rule 7: etcd server (Ports 2379-2380) - Internal only
resource "azurerm_network_security_rule" "etcd" {
  count                       = var.create_nsg_rules ? 1 : 0
  name                        = "AllowEtcd"
  description                 = "Allow etcd server communication - internal VNet only"
  priority                    = 160
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["2379", "2380"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Rule 8: NodePort Services (Ports 30000-32767) - Optional
resource "azurerm_network_security_rule" "nodeport" {
  count                       = var.create_nsg_rules && length(var.nodeport_source_cidrs) > 0 ? 1 : 0
  name                        = "AllowNodePort"
  description                 = "Allow NodePort Service access"
  priority                    = 170
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "30000-32767"
  source_address_prefixes     = var.nodeport_source_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.nsg_name

  depends_on = [
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Associate k8s NSG with k8s subnet
resource "azurerm_subnet_network_security_group_association" "nsg_k8s" {
  subnet_id                 = local.subnets["k8s"].id
  network_security_group_id = var.nsg_name == null ? azurerm_network_security_group.nsg[0].id : data.azurerm_network_security_group.existing[0].id

  depends_on = [
    azurerm_subnet.subnet,
    data.azurerm_subnet.existing,
    azurerm_network_security_group.nsg,
    data.azurerm_network_security_group.existing
  ]
}

# Associate misc NSG with misc subnet (jump/nfs)
resource "azurerm_subnet_network_security_group_association" "nsg_misc" {
  subnet_id                 = local.subnets["misc"].id
  network_security_group_id = var.misc_nsg_name == null ? azurerm_network_security_group.nsg_misc[0].id : data.azurerm_network_security_group.existing_misc[0].id

  depends_on = [
    azurerm_subnet.subnet,
    data.azurerm_subnet.existing,
    azurerm_network_security_group.nsg_misc,
    data.azurerm_network_security_group.existing_misc
  ]
}

# NFS ports on misc NSG - allow k8s nodes to mount NFS server
resource "azurerm_network_security_rule" "nfs" {
  count                       = var.create_nsg_rules ? 1 : 0
  name                        = "AllowNFS"
  description                 = "Allow NFS traffic from k8s nodes to NFS server"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["111", "2049"]
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = local.misc_nsg_name

  depends_on = [
    azurerm_network_security_group.nsg_misc,
    data.azurerm_network_security_group.existing_misc
  ]
}

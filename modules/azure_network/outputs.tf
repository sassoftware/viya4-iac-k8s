# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = var.vnet_name == null ? azurerm_virtual_network.vnet[0].id : data.azurerm_virtual_network.existing[0].id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = local.vnet_name
}

output "vnet_address_space" {
  description = "Address space of the Virtual Network"
  value       = var.vnet_name == null ? azurerm_virtual_network.vnet[0].address_space : data.azurerm_virtual_network.existing[0].address_space
}

output "subnet_ids" {
  description = "Map of subnet names to their IDs"
  value = {
    for k, v in local.subnets : k => v.id
  }
}

output "subnet_details" {
  description = "Map of subnet names to their full details (id, name, address_prefixes)"
  value       = local.subnets
}

output "nsg_id" {
  description = "ID of the k8s Network Security Group"
  value       = var.nsg_name == null ? azurerm_network_security_group.nsg[0].id : data.azurerm_network_security_group.existing[0].id
}

output "nsg_name" {
  description = "Name of the k8s Network Security Group"
  value       = local.nsg_name
}

output "nsg_misc_id" {
  description = "ID of the misc (jump/nfs) Network Security Group"
  value       = var.misc_nsg_name == null ? azurerm_network_security_group.nsg_misc[0].id : data.azurerm_network_security_group.existing_misc[0].id
}

output "nsg_misc_name" {
  description = "Name of the misc (jump/nfs) Network Security Group"
  value       = local.misc_nsg_name
}

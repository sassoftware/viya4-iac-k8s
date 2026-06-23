# Module Outputs - Information about created VM resources

output "vm_id" {
  value       = azurerm_linux_virtual_machine.vm.id
  description = "Azure resource ID of the virtual machine"
}

output "vm_name" {
  value       = azurerm_linux_virtual_machine.vm.name
  description = "Name of the virtual machine"
}

output "vm_principal_id" {
  value       = azurerm_linux_virtual_machine.vm.identity[*].principal_id
  description = "Principal ID of the VM if system-assigned identity is enabled"
}

output "private_ip_address" {
  value       = azurerm_network_interface.vm.private_ip_address
  description = "Private IP address of the VM"
}

output "public_ip_address" {
  value       = var.assign_public_ip ? azurerm_public_ip.vm[0].ip_address : null
  description = "Public IP address of the VM (if assigned)"
}

output "public_ip_id" {
  value       = var.assign_public_ip ? azurerm_public_ip.vm[0].id : null
  description = "Azure resource ID of the public IP address"
}

output "network_interface_id" {
  value       = azurerm_network_interface.vm.id
  description = "Azure resource ID of the network interface"
}

output "network_interface_ids" {
  value       = [azurerm_network_interface.vm.id]
  description = "Azure resource IDs of all network interfaces"
}

output "data_disk_ids" {
  value       = [for disk in azurerm_managed_disk.data_disk : disk.id]
  description = "List of Azure resource IDs for data disks"
}

output "os_disk_id" {
  value       = azurerm_linux_virtual_machine.vm.os_disk[0].id
  description = "Azure resource ID of the OS disk"
}

output "kubernetes_node_info" {
  value = {
    node_name = azurerm_linux_virtual_machine.vm.name
    taints    = var.node_taints
    labels    = var.node_labels
  }
  description = "Kubernetes node configuration (taints and labels)"
}

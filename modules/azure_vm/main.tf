# Azure VM Module for Kubernetes Cluster Nodes
# Supports creating VMs with network interfaces, data disks, and cloud-init provisioning

locals {
  # Normalize vm_name by removing/replacing invalid characters
  vm_name_normalized = replace(var.vm_name, "_", "-")

  # Create cloud-init script if provided, otherwise empty
  cloud_init_script = var.cloud_init_enabled && var.cloud_init_script != "" ? base64encode(var.cloud_init_script) : ""
}

# Public IP Address (optional, for jump and NFS servers)
resource "azurerm_public_ip" "vm" {
  count = var.assign_public_ip ? 1 : 0

  name                = "${local.vm_name_normalized}-pip"
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Name = "${local.vm_name_normalized}-public-ip"
    }
  )
}

# Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "${local.vm_name_normalized}-nic"
  location            = var.azure_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "testConfiguration"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.assign_public_ip ? azurerm_public_ip.vm[0].id : null
  }

  tags = merge(
    var.tags,
    {
      Name = "${local.vm_name_normalized}-nic"
    }
  )
}

# Associate Network Security Group with Network Interface
resource "azurerm_network_interface_security_group_association" "vm" {
  count = var.nsg_id != "" ? 1 : 0

  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = var.nsg_id
}

# Managed Disks for additional storage (data disks)
resource "azurerm_managed_disk" "data_disk" {
  for_each = {
    for idx, disk_size in var.data_disk_sizes : idx => disk_size
  }

  name                 = "${local.vm_name_normalized}-datadisk-${each.key}"
  location             = var.azure_location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_storage_type
  create_option        = "Empty"
  disk_size_gb         = each.value

  tags = merge(
    var.tags,
    {
      Name = "${local.vm_name_normalized}-data-disk-${each.key}"
    }
  )
}

# Attach data disks to VM
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk" {
  for_each = {
    for idx, disk_size in var.data_disk_sizes : idx => disk_size
  }

  managed_disk_id    = azurerm_managed_disk.data_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = each.key
  caching            = "ReadWrite"

  depends_on = [azurerm_linux_virtual_machine.vm]
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = local.vm_name_normalized
  location            = var.azure_location
  resource_group_name = var.resource_group_name
  size                = var.vm_size

  admin_username                  = var.admin_username
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_type
    disk_size_gb         = var.os_disk_size
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  # Cloud-init provisioning
  custom_data = local.cloud_init_script != "" ? local.cloud_init_script : null

  tags = merge(
    var.tags,
    var.node_labels,
    {
      Name = local.vm_name_normalized
    }
  )

  depends_on = [
    azurerm_network_interface_security_group_association.vm
  ]

  lifecycle {
    ignore_changes = [
      tags,
      custom_data
    ]
  }
}

# Apply Kubernetes node taints and labels via cloud-init (advanced)
# Note: Taints are typically applied at cluster bootstrap time, not during VM creation
# This serves as documentation of intended taints for the node
locals {
  kubernetes_node_info = {
    taints = var.node_taints
    labels = var.node_labels
  }
}

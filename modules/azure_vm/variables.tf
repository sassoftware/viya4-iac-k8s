// Input Variables for Azure VM Module (copied)

variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group"
}

variable "azure_location" {
  type        = string
  description = "Azure region where resources will be created"
}

variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
}

variable "vm_size" {
  type        = string
  description = "Azure VM size"
}

variable "os_disk_size" {
  type        = number
  default     = 100
}

variable "os_disk_storage_type" {
  type    = string
  default = "Standard_LRS"
}

variable "data_disk_sizes" {
  type    = list(number)
  default = []
}

variable "data_disk_storage_type" {
  type    = string
  default = "Standard_LRS"
}

variable "subnet_id" {
  type = string
}

variable "nsg_id" {
  type    = string
  default = ""
}

variable "create_nsg_association" {
  type    = bool
  default = true
}

variable "assign_public_ip" {
  type    = bool
  default = false
}

variable "accelerated_networking" {
  type    = bool
  default = false
}

variable "image_publisher" {
  type    = string
  default = "Canonical"
}

variable "image_offer" {
  type    = string
  default = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  type    = string
  default = "22_04-lts-gen2"
}

variable "image_version" {
  type    = string
  default = "latest"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "cloud_init_enabled" {
  type    = bool
  default = false
}

variable "cloud_init_script" {
  type    = string
  default = ""
}

variable "node_taints" {
  type    = list(string)
  default = []
}

variable "node_labels" {
  type    = map(string)
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}

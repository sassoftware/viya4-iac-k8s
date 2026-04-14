# Input Variables for Azure VM Module

# Azure Infrastructure
variable "resource_group_name" {
  type        = string
  description = "Name of the Azure resource group"
  nullable    = false
}

variable "azure_location" {
  type        = string
  description = "Azure region where resources will be created"
  nullable    = false
}

# VM Configuration
variable "vm_name" {
  type        = string
  description = "Name of the virtual machine"
  nullable    = false
}

variable "vm_size" {
  type        = string
  description = "Azure VM size (e.g., Standard_D4s_v5, Standard_E16s_v5)"
  nullable    = false

  validation {
    condition     = can(regex("^Standard_[A-Z][0-9]+s?_v[0-9]$", var.vm_size))
    error_message = "VM size must be a valid Azure Standard SKU (e.g., Standard_D4s_v5)"
  }
}

# OS Disk Configuration
variable "os_disk_size" {
  type        = number
  description = "OS disk size in GB"
  default     = 100
  nullable    = false

  validation {
    condition     = var.os_disk_size >= 30 && var.os_disk_size <= 4096
    error_message = "OS disk size must be between 30 and 4096 GB"
  }
}

variable "os_disk_storage_type" {
  type        = string
  description = "OS disk storage type (Premium_LRS, Standard_LRS, StandardSSD_LRS)"
  default     = "Standard_LRS"
  nullable    = false

  validation {
    condition     = contains(["Premium_LRS", "Standard_LRS", "StandardSSD_LRS"], var.os_disk_storage_type)
    error_message = "OS disk storage type must be Premium_LRS, Standard_LRS, or StandardSSD_LRS"
  }
}

# Data Disks Configuration
variable "data_disk_sizes" {
  type        = list(number)
  description = "List of data disk sizes in GB (e.g., [256, 512] for 2 disks)"
  default     = []
  nullable    = false
}

variable "data_disk_storage_type" {
  type        = string
  description = "Data disk storage type (Premium_LRS, Standard_LRS, StandardSSD_LRS)"
  default     = "Standard_LRS"
  nullable    = false

  validation {
    condition     = contains(["Premium_LRS", "Standard_LRS", "StandardSSD_LRS"], var.data_disk_storage_type)
    error_message = "Data disk storage type must be Premium_LRS, Standard_LRS, or StandardSSD_LRS"
  }
}

# Networking
variable "subnet_id" {
  type        = string
  description = "Azure subnet ID where VM will be deployed"
  nullable    = false
}

variable "nsg_id" {
  type        = string
  description = "Azure Network Security Group ID to associate with NIC (optional)"
  default     = ""
  nullable    = false
}

variable "create_nsg_association" {
  type        = bool
  description = "Whether to create NSG association (set based on deployment_type at plan time)"
  default     = true
  nullable    = false
}

variable "assign_public_ip" {
  type        = bool
  description = "Whether to assign a public IP address to the VM"
  default     = false
  nullable    = false
}

variable "accelerated_networking" {
  type        = bool
  description = "Enable accelerated networking on the network interface"
  default     = false
  nullable    = false
}

# Operating System Image
variable "image_publisher" {
  type        = string
  description = "VM image publisher (e.g., Canonical)"
  default     = "Canonical"
  nullable    = false
}

variable "image_offer" {
  type        = string
  description = "VM image offer (e.g., 0001-com-ubuntu-server-jammy)"
  default     = "0001-com-ubuntu-server-jammy"
  nullable    = false
}

variable "image_sku" {
  type        = string
  description = "VM image SKU (e.g., 22_04-lts-gen2)"
  default     = "22_04-lts-gen2"
  nullable    = false
}

variable "image_version" {
  type        = string
  description = "VM image version (e.g., latest, or specific version)"
  default     = "latest"
  nullable    = false
}

# SSH and Admin Access
variable "admin_username" {
  type        = string
  description = "Administrator username for the VM"
  default     = "azureuser"
  nullable    = false
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
  nullable    = false
  sensitive   = true
}

# Cloud-Init Provisioning
variable "cloud_init_enabled" {
  type        = bool
  description = "Whether to enable cloud-init for VM provisioning"
  default     = false
  nullable    = false
}

variable "cloud_init_script" {
  type        = string
  description = "Cloud-init script for VM initialization (base64 encoded by module)"
  default     = ""
  nullable    = false
}

# Kubernetes Node Configuration
variable "node_taints" {
  type        = list(string)
  description = "Kubernetes node taints (e.g., [\"node-role.kubernetes.io/control-plane:NoSchedule\"])"
  default     = []
  nullable    = false
}

variable "node_labels" {
  type        = map(string)
  description = "Kubernetes node labels (e.g., {\"workload.sas.com/class\" = \"compute\"})"
  default     = {}
  nullable    = false
}

# Tagging
variable "tags" {
  type        = map(string)
  description = "Azure resource tags"
  default     = {}
  nullable    = false
}

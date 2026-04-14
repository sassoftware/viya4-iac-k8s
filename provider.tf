# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# PROVIDER CONFIGURATION
# =============================================================================
# Terraform providers are ALWAYS initialized, even if no resources use them.
# Comment/uncomment the appropriate provider based on your deployment_type:
#
#   deployment_type = "bare_metal" -> Comment out BOTH providers (Ansible only)
#   deployment_type = "azure"      -> Uncomment azurerm, comment vsphere
#   deployment_type = "vsphere"    -> Uncomment vsphere, comment azurerm
# =============================================================================

# --- Azure Provider (for deployment_type = "azure") ---
provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  use_msi = var.azure_use_msi

  features {}

  resource_provider_registrations = "none"
}

# --- vSphere Provider (for deployment_type = "vsphere") ---
# Uncomment when using vsphere deployment type
#
# provider "vsphere" {
#   user           = var.vsphere_user
#   password       = var.vsphere_password
#   vsphere_server = var.vsphere_server
#
#   # If you have a self-signed cert
#   allow_unverified_ssl = true
# }

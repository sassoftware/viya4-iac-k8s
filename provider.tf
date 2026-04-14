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

# --- vSphere Provider ---
# For Azure deployments: provide dummy values (provider won't be used since all vsphere modules have count=0)
# For vsphere deployments: provide actual credentials
provider "vsphere" {
  user           = var.deployment_type == "vsphere" ? var.vsphere_user : "dummy"
  password       = var.deployment_type == "vsphere" ? var.vsphere_password : "dummy"
  vsphere_server = var.deployment_type == "vsphere" ? var.vsphere_server : "localhost"

  # If you have a self-signed cert
  allow_unverified_ssl = true
}


# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret

  use_msi = var.azure_use_msi

  features {}

  resource_provider_registrations = "none"
}

# vSphere provider is declared in vsphere_compute.tf.disabled and activated
# by oss-k8s.sh (setup_providers) only for DEPLOYMENT_TYPE=vsphere.
# Keeping it out of static files prevents Terraform from initialising a
# vsphere connection for azure/bare_metal runs.


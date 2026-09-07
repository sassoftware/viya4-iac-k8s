# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Provider configuration for standalone execution from this directory.
#
# required_providers is declared once in the root versions.tf; do not duplicate it here.
#
# All four provider blocks stay uncommented (deployment_type = "openstack" here).
# Terraform validates every provider in required_providers for the whole config
# graph regardless of count, so azurerm/vsphere still need valid schema (features{},
# non-null user/password) even though their topology modules have count = 0.

provider "azurerm" {
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  use_msi         = var.azure_use_msi

  features {}
  resource_provider_registrations = "none"
}

provider "openstack" {
  auth_url    = var.openstack_auth_url
  user_name   = var.openstack_user_name
  password    = var.openstack_password
  tenant_name = var.openstack_tenant_name
  domain_name = var.openstack_domain_name
  region      = var.openstack_region
  insecure    = true
  cacert_file = var.openstack_cacert_file
}

provider "vsphere" {
  vsphere_server       = coalesce(var.vsphere_server, "unused")
  user                 = coalesce(var.vsphere_user, "unused")
  password             = coalesce(var.vsphere_password, "unused")
  allow_unverified_ssl = true
}
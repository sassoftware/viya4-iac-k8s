# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
# Provider configuration for standalone execution from this directory.
# Copy this file to provider.tf and fill in your credentials, OR use
# environment variables (OS_AUTH_URL, OS_USERNAME, OS_PASSWORD, etc.).


provider "openstack" {
  auth_url    = var.openstack_auth_url
  user_name   = var.openstack_user_name
  password    = var.openstack_password
  tenant_name = var.openstack_tenant_name
  domain_name = var.openstack_domain_name
  region      = var.openstack_region
  insecure    = var.openstack_insecure
  cacert_file = var.openstack_cacert_file
}

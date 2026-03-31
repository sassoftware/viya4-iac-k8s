# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# NOTE: This file is overwritten at runtime by oss-k8s.sh based on SYSTEM=vsphere|openstack.
# The openstack form below is the committed baseline used for static linting in CI.

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

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

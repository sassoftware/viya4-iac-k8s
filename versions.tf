# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.48"
    }
    # vsphere provider is declared in vsphere_compute.tf (activated by oss-k8s.sh
    # only for DEPLOYMENT_TYPE=vsphere). Keeping it out of static files prevents
    # Terraform from initialising a vsphere connection for azure/bare_metal runs.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

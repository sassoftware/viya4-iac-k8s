# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.48"
    }
    # IMPORTANT: Uncomment vsphere below ONLY when deployment_type = "vsphere"
    # For azure/bare_metal deployments, keep vsphere commented out
    # vsphere = {
    #   source  = "hashicorp/vsphere"
    #   version = "~> 2.6"
    # }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

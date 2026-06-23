# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Root dispatcher — declares all provider plugins required across all topologies
# so that `terraform init` downloads them in one pass.
#
# Provider CONFIGURATION (credentials/endpoints) lives in the root provider.tf.
# Credentials are passed via environment variables (preferred) or tfvars files.
# Only the active topology's resources are created (inactive modules use count=0).
#
# For STANDALONE topology execution:
#   cd topologies/<name>
#   cp provider.tf.example provider.tf   # fill in credentials
#   terraform init && terraform apply

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.48"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
  }
}


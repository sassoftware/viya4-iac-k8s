# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# NOTE: The vSphere provider is configured when using this topology standalone.
# Create a local provider.tf from provider.tf.example and fill in credentials,
# or use VSPHERE_USER / VSPHERE_PASSWORD / VSPHERE_SERVER environment variables.

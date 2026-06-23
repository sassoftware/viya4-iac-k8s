# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# NOTE: Provider credentials are supplied via OS_* environment variables (recommended),
# or by placing a provider.tf at the repo root (see root provider.tf.example).
# For standalone execution from this directory, copy provider.tf.example to provider.tf.

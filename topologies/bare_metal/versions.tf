# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# NOTE: The bare_metal topology has no cloud provider. No provider credentials
# are needed — Terraform is used solely to generate the Ansible inventory and
# ansible-vars.yaml from node IP addresses supplied in the tfvars file.
# Task 2.11: verified — no cloud provider download occurs for bare metal runs.

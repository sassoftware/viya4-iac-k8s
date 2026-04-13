# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# !NOTE! - These variables are examples for Azure deployment.
# Customize this file to add any variables from 'CONFIG-VARS.md' whose default
# values you want to change.

# ****************  REQUIRED VARIABLES  ****************
# These required variables' values MUST be provided by the User

# Deployment type
deployment_type = "azure"

# Azure Authentication - DO NOT COMMIT SECRETS TO VERSION CONTROL
# It is HIGHLY RECOMMENDED to use environment variables instead:
#
# export TF_VAR_azure_subscription_id="00000000-0000-0000-0000-000000000000"
# export TF_VAR_azure_tenant_id="00000000-0000-0000-0000-000000000000"
# export TF_VAR_azure_client_id="00000000-0000-0000-0000-000000000000"
# export TF_VAR_azure_client_secret="your-secret-here"
#
# If you must use this file (NOT recommended for production):
# azure_subscription_id = "00000000-0000-0000-0000-000000000000"
# azure_tenant_id       = "00000000-0000-0000-0000-000000000000"
# azure_client_id       = "00000000-0000-0000-0000-000000000000"
# azure_client_secret   = "your-secret-here"

# Azure resource settings
azure_resource_group = "my-k8s-resource-group"
azure_location       = "eastus"  # Options: eastus, westus2, centralus, etc.

# ****************  REQUIRED VARIABLES  ****************

# **************  RECOMMENDED  VARIABLES  ***************

# Alternative: Use Managed Identity (when running Terraform on an Azure VM)
# This is more secure than using a Service Principal
# azure_use_msi = true

# NOTE: When using Managed Identity, you still need to provide:
# - azure_subscription_id
# - azure_tenant_id
# But you do NOT need azure_client_id or azure_client_secret

# **************  RECOMMENDED  VARIABLES  ***************

# Additional configuration examples:
# See CONFIG-VARS.md for all available variables

# Example: Node pools configuration
# node_pools = {
#   control_plane = {
#     count = 3
#     cpus = 4
#     memory = 8192
#     os_disk = 100
#   }
#   system = {
#     count = 3
#     cpus = 8
#     memory = 16384
#     os_disk = 200
#     node_labels = {
#       "kubernetes.azure.com/mode" = "system"
#     }
#   }
#   compute = {
#     count = 2
#     cpus = 16
#     memory = 32768
#     os_disk = 200
#   }
# }

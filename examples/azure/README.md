# Azure examples

This directory contains example Terraform variable files for Azure.

- `sample-terraform-azure.tfvars` — sample `terraform.tfvars` for Azure deployments.

Notes:
- `azure_create_network` and `azure_create_api_lb` are disabled by default in the sample to avoid accidental network modifications and charges. Set them to `true` only when you want Terraform to create a VNet/subnets/NSGs and the API Load Balancer.
- If you do not enable `azure_create_network`, provide `azure_subnet_id` and (optionally) `azure_nsg_id` that point to existing network resources.
- After provisioning, update DNS records for the API VIP and LoadBalancer addresses as described in `docs/user/AzureUsage.md`.

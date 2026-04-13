# Azure Deployment Examples

This directory contains example Terraform variable files (`.tfvars`) for deploying Kubernetes clusters on Azure VMs using viya4-iac-k8s.

## Prerequisites

Before using these examples, ensure you have:

1. **Azure CLI** installed and configured
2. **Terraform** >= 1.10.0 installed
3. **Azure credentials** configured (see [AzureAuthentication.md](../../docs/user/AzureAuthentication.md))
4. An **Azure Subscription** with appropriate permissions

## Authentication Setup

See the detailed [Azure Authentication Guide](../../docs/user/AzureAuthentication.md) for step-by-step instructions on:
- Creating a Service Principal
- Setting up Managed Identity
- Configuring environment variables

## Quick Start

1. **Set up authentication** (use environment variables):

```bash
export TF_VAR_azure_subscription_id="your-subscription-id"
export TF_VAR_azure_tenant_id="your-tenant-id"
export TF_VAR_azure_client_id="your-client-id"
export TF_VAR_azure_client_secret="your-client-secret"
```

2. **Copy an example file**:

```bash
cp examples/azure/sample-terraform-azure.tfvars terraform.tfvars
```

3. **Edit the file** to customize your deployment:

```bash
vim terraform.tfvars
```

4. **Deploy**:

```bash
terraform init
terraform plan
terraform apply
```

## Example Files

### sample-terraform-azure.tfvars
Basic Azure deployment example with minimal configuration.

**Use case**: Quick start and testing

## Important Notes

### Security
- **NEVER commit credentials** to version control
- Use environment variables for sensitive values
- Consider using Azure Key Vault for production deployments
- Managed Identity is preferred when running Terraform from an Azure VM

### Resource Naming
- Azure resource names must be unique within your subscription
- The `azure_resource_group` will be created if it doesn't exist
- Choose your `azure_location` based on your requirements (latency, compliance, etc.)

### Costs
Azure resources incur costs. Be sure to:
- Understand Azure pricing before deploying
- Use `terraform destroy` to clean up resources when done
- Monitor your Azure costs in the Azure Portal

## Additional Documentation

- [Main README](../../README.md)
- [Azure Authentication Guide](../../docs/user/AzureAuthentication.md)
- [Configuration Variables Reference](../../docs/CONFIG-VARS.md)

## Support

For issues specific to Azure deployments, please refer to:
- [Azure Help Topics](https://docs.microsoft.com/en-us/azure/)
- Project issue tracker

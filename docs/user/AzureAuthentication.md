# Authenticating Terraform to Access Microsoft Azure

In order to create and destroy Microsoft Azure resources on your behalf, Terraform needs an identity with sufficient permissions to perform all the actions defined in the Terraform manifest. You can use a **Service Principal** or, when running on an Azure VM, a **User-assigned Managed Identity** to grant Terraform access to your Azure subscription.

Your Service Principal or Managed Identity in the Azure subscription requires a **"Contributor"** role to create Azure resources.

## Prerequisites

- Azure Subscription
- Azure CLI installed (`az` command)
- Appropriate permissions to create Service Principals or Managed Identities

## Authentication Methods

### Method 1: Using a Service Principal (Recommended for CI/CD)

A Service Principal is an identity created for use with automated tools like Terraform.

#### Step 1: Create a Service Principal

```bash
# Login to Azure
az login

# Create a Service Principal with Contributor role
az ad sp create-for-rbac --name "terraform-sp" --role="Contributor" --scopes="/subscriptions/<SUBSCRIPTION_ID>"
```

This command will output:
```json
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "terraform-sp",
  "password": "your-client-secret",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```

#### Step 2: Retrieve Required Values

```bash
# Get your Subscription ID
az account show --query id -o tsv

# Get your Tenant ID
az account show --query tenantId -o tsv
```

#### Step 3: Set Environment Variables

The recommended approach is to use environment variables to avoid committing secrets to version control:

```bash
export TF_VAR_azure_subscription_id="<SUBSCRIPTION_ID>"
export TF_VAR_azure_tenant_id="<TENANT_ID>"
export TF_VAR_azure_client_id="<appId from Step 1>"
export TF_VAR_azure_client_secret="<password from Step 1>"
```

**Security Best Practice**: Add these exports to your shell profile (`.bashrc`, `.zshrc`) or use a secrets management tool. Never commit these values to version control.

#### Step 4: Update Your tfvars File

In your `terraform.tfvars` or custom `.tfvars` file:

```hcl
deployment_type      = "azure"
azure_resource_group = "my-k8s-rg"
azure_location       = "eastus"

# Do NOT set credentials here - use environment variables instead
# azure_subscription_id = "..." # NO!
# azure_client_secret   = "..." # NO!
```

### Method 2: Using Managed Identity (Recommended when running on Azure VM)

Managed Identity provides an automatically managed identity in Azure AD for applications to use when connecting to resources.

#### Step 1: Create a User-Assigned Managed Identity

```bash
# Create a managed identity
az identity create \
  --name terraform-identity \
  --resource-group my-rg \
  --location eastus

# Get the identity's principal ID
IDENTITY_ID=$(az identity show \
  --name terraform-identity \
  --resource-group my-rg \
  --query principalId -o tsv)

# Assign Contributor role to the identity
az role assignment create \
  --assignee $IDENTITY_ID \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

#### Step 2: Assign the Managed Identity to Your Azure VM

```bash
az vm identity assign \
  --name my-vm \
  --resource-group my-rg \
  --identities terraform-identity
```

#### Step 3: Configure Terraform Variables

Set only these environment variables when using Managed Identity:

```bash
export TF_VAR_azure_subscription_id="<SUBSCRIPTION_ID>"
export TF_VAR_azure_tenant_id="<TENANT_ID>"
export TF_VAR_azure_use_msi=true
```

In your `terraform.tfvars`:

```hcl
deployment_type      = "azure"
azure_resource_group = "my-k8s-rg"
azure_location       = "eastus"
azure_use_msi        = true
```

## Required Terraform Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `azure_subscription_id` | Your Azure Subscription ID | Yes | null |
| `azure_tenant_id` | Your Azure Tenant ID | Yes | null |
| `azure_client_id` | Service Principal App ID | Yes (unless using MSI) | null |
| `azure_client_secret` | Service Principal Password | Yes (unless using MSI) | null |
| `azure_use_msi` | Use Managed Identity | No | false |
| `azure_resource_group` | Resource group name | Recommended | null |
| `azure_location` | Azure region | Recommended | "eastus" |

## Verification

After setting up authentication, verify it works:

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (dry-run)
terraform plan
```

If authentication is configured correctly, you should see no authentication errors.

## Security Best Practices

1. **Never commit secrets to version control**
   - Add `*.tfvars` with secrets to `.gitignore`
   - Use environment variables or secret management tools

2. **Use Managed Identity when possible**
   - More secure than Service Principals
   - No credential rotation needed
   - Only works when running Terraform from an Azure VM

3. **Limit Service Principal permissions**
   - Use the principle of least privilege
   - Create separate Service Principals per environment
   - Regularly rotate client secrets

4. **Use Azure Key Vault**
   - Store sensitive values in Azure Key Vault
   - Reference them in Terraform using data sources

## Troubleshooting

### Error: "unauthorized_client"
- Verify your `client_id` and `client_secret` are correct
- Ensure the Service Principal has not expired
- Check that the Service Principal has the Contributor role

### Error: "AADSTS700016"
- The `client_id` (Application ID) is incorrect
- Double-check you copied the `appId` from the Service Principal creation

### Error: "insufficient privileges"
- The Service Principal or Managed Identity lacks the Contributor role
- Assign the role using: `az role assignment create --assignee <principal-id> --role Contributor`

## Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)
- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Service Principals](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Azure Managed Identities](https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview)

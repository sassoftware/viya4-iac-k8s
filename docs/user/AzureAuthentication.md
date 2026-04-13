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

---

## Azure Networking Configuration

After setting up authentication, configure your Azure networking for the Kubernetes deployment.

### Quick Start (New VNet)

For most deployments, let Terraform create the networking resources automatically:

```hcl
deployment_type      = "azure"
azure_resource_group = "my-k8s-rg"
azure_location       = "eastus"

# VNet will be created with this address space
azure_vnet_address_space = "192.168.0.0/16"

# Security: Define which IP addresses can access your infrastructure
azure_default_public_access_cidrs = [
  "203.0.113.0/24"  # Replace with your office/VPN IP range
]
```

This creates:
- A VNet with address space `192.168.0.0/16`
- A subnet for Kubernetes nodes (`192.168.0.0/22` - 1024 IPs)
- A subnet for infrastructure VMs (`192.168.4.0/24` - 256 IPs)
- Network Security Group with rules for SSH and Kubernetes API

### Using Existing VNet (Bring Your Own Network)

To use an existing VNet and subnets:

```hcl
deployment_type      = "azure"
azure_resource_group = "my-k8s-rg"
azure_location       = "eastus"

# Use existing network resources
azure_vnet_name                = "my-existing-vnet"
azure_vnet_resource_group_name = "my-network-rg"
azure_nsg_name                 = "my-existing-nsg"

# Map to existing subnet names
azure_subnet_names = {
  k8s  = "kubernetes-subnet"
  misc = "infrastructure-subnet"
}

# Optional: Don't create new NSG rules if using existing NSG
azure_create_nsg_rules = false
```

**Prerequisites for Existing VNet:**
- VNet must exist in the same Azure region
- Subnets must have sufficient IP addresses:
  - k8s subnet: At least `/22` (1024 IPs) recommended
  - misc subnet: At least `/24` (256 IPs) recommended
- NSG must allow:
  - Inbound SSH (port 22) to VMs
  - Inbound Kubernetes API (port 6443) to control plane nodes
  - Internal communication between nodes

### Network Security Configuration

**IMPORTANT**: Always restrict public access to your infrastructure. Never use `0.0.0.0/0` in production.

#### Option 1: Same CIDRs for All Resources (Recommended)

```hcl
# This CIDR list applies to SSH, K8s API, and all other access
azure_default_public_access_cidrs = [
  "203.0.113.0/24",   # Office network
  "198.51.100.0/24"   # VPN network
]
```

#### Option 2: Granular Access Control

```hcl
# Default CIDRs (fallback)
azure_default_public_access_cidrs = ["203.0.113.0/24"]

# Override for specific resources
azure_vm_public_access_cidrs = [
  "203.0.113.100/32"  # Only this IP can SSH to VMs
]

azure_cluster_endpoint_public_access_cidrs = [
  "203.0.113.0/24",   # Office network can access K8s API
  "198.51.100.0/24"   # VPN network can access K8s API
]
```

### Custom Subnet Configuration

To customize subnet sizes or add service endpoints:

```hcl
azure_subnets = {
  k8s = {
    prefixes          = ["192.168.0.0/21"]  # 2048 IPs for larger clusters
    service_endpoints = []
  }
  misc = {
    prefixes          = ["192.168.8.0/24"]  # 256 IPs for infrastructure
    service_endpoints = []
  }
}
```

### Custom DNS Servers

To use your own DNS servers instead of Azure-provided DNS:

```hcl
azure_use_custom_dns     = true
azure_custom_dns_servers = [
  "10.0.0.4",
  "10.0.0.5"
]
```

**Note**: Ensure your custom DNS servers can resolve:
- Azure service endpoints
- Public internet (for package downloads, container images)
- Internal cluster DNS requirements

### Network Performance Options

```hcl
# Enable public IPs for VMs (needed for external access)
azure_vm_public_ip_enabled = true

# Enable accelerated networking (better performance on supported VM sizes)
azure_accelerated_networking = true
```

**Accelerated Networking Benefits:**
- Reduced latency
- Lower CPU usage
- Higher throughput
- Available on most modern VM sizes (D-series, E-series, F-series, etc.)

### Azure Networking Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `azure_vnet_resource_group_name` | Resource group of existing VNet | null | No |
| `azure_vnet_name` | Name of existing VNet | null | No |
| `azure_vnet_address_space` | CIDR for new VNet | "192.168.0.0/16" | No |
| `azure_subnet_names` | Map of existing subnet names | {} | No |
| `azure_subnets` | Subnet configuration | See defaults | No |
| `azure_nsg_name` | Name of existing NSG | null | No |
| `azure_create_nsg_rules` | Auto-create NSG rules | true | No |
| `azure_default_public_access_cidrs` | Default access CIDRs | null | **Yes** |
| `azure_vm_public_access_cidrs` | VM SSH access CIDRs | Uses default | No |
| `azure_cluster_endpoint_public_access_cidrs` | K8s API access CIDRs | Uses default | No |
| `azure_vm_public_ip_enabled` | Enable public IPs for VMs | true | No |
| `azure_accelerated_networking` | Enable accelerated networking | true | No |
| `azure_use_custom_dns` | Use custom DNS servers | false | No |
| `azure_custom_dns_servers` | Custom DNS server IPs | [] | If custom DNS enabled |

### Network Planning Guide

#### Small Development Cluster (< 10 nodes)
```hcl
azure_vnet_address_space = "192.168.0.0/16"
azure_subnets = {
  k8s  = { prefixes = ["192.168.0.0/24"], service_endpoints = [] }  # 256 IPs
  misc = { prefixes = ["192.168.1.0/24"], service_endpoints = [] }  # 256 IPs
}
```

#### Medium Production Cluster (10-50 nodes)
```hcl
azure_vnet_address_space = "192.168.0.0/16"
azure_subnets = {
  k8s  = { prefixes = ["192.168.0.0/22"], service_endpoints = [] }  # 1024 IPs
  misc = { prefixes = ["192.168.4.0/24"], service_endpoints = [] }  # 256 IPs
}
```

#### Large Production Cluster (50+ nodes)
```hcl
azure_vnet_address_space = "10.0.0.0/16"
azure_subnets = {
  k8s  = { prefixes = ["10.0.0.0/20"], service_endpoints = [] }    # 4096 IPs
  misc = { prefixes = ["10.0.16.0/24"], service_endpoints = [] }   # 256 IPs
}
```

### Troubleshooting Network Issues

#### Issue: Cannot SSH to VMs
**Possible Causes:**
- Public IP not enabled: Set `azure_vm_public_ip_enabled = true`
- CIDR not configured: Set `azure_default_public_access_cidrs` to include your IP
- NSG rules not created: Verify `azure_create_nsg_rules = true`

**Solution:**
```bash
# Check your current public IP
curl ifconfig.me

# Ensure this IP is in your access CIDRs
# If not, add it to your terraform.tfvars and re-apply
```

#### Issue: Cannot access Kubernetes API
**Possible Causes:**
- Control plane node has no public IP
- Firewall blocking port 6443
- Incorrect CIDR configuration

**Solution:**
Ensure `azure_cluster_endpoint_public_access_cidrs` includes your IP or use `azure_default_public_access_cidrs`.

#### Issue: Subnet has insufficient IP addresses
**Symptoms:**
- New VMs fail to create
- "No available IPs" error

**Solution:**
Use larger subnet CIDR blocks. For example, change from `/24` to `/22` (4x more IPs).

### Best Practices

1. **Always use restrictive CIDRs** - Never use `0.0.0.0/0` in production
2. **Plan for growth** - Use larger subnets than currently needed
3. **Use existing VNets** for production to integrate with existing network infrastructure
4. **Enable accelerated networking** for better performance
5. **Document your network layout** - Keep CIDR allocations documented
6. **Use Network Security Groups** - Leverage Azure NSG for defense in depth
7. **Monitor network costs** - Public IPs and data transfer have costs

### Example Complete Configuration

```hcl
# Azure authentication (set via environment variables)
# export TF_VAR_azure_subscription_id="..."
# export TF_VAR_azure_tenant_id="..."
# export TF_VAR_azure_client_id="..."
# export TF_VAR_azure_client_secret="..."

# Deployment configuration
deployment_type      = "azure"
azure_resource_group = "prod-k8s-rg"
azure_location       = "eastus"

# Network configuration
azure_vnet_address_space = "10.100.0.0/16"
azure_subnets = {
  k8s = {
    prefixes          = ["10.100.0.0/20"]   # 4096 IPs for K8s
    service_endpoints = []
  }
  misc = {
    prefixes          = ["10.100.16.0/24"]  # 256 IPs for infra
    service_endpoints = []
  }
}

# Security - restrict access to office network
azure_default_public_access_cidrs = ["203.0.113.0/24"]

# Network features
azure_vm_public_ip_enabled   = true
azure_accelerated_networking = true
azure_create_nsg_rules       = true

# Node configuration
node_pools = {
  control_plane = {
    count  = 3
    cpus   = 4
    memory = 16384
    # ... additional configuration
  }
  # ... other node pools
}
```

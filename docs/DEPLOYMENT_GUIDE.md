# Deployment Guide — viya4-iac-k8s

## Prerequisites

- Terraform >= 1.10.0
- Ansible >= 2.14
- Azure CLI (or Service Principal credentials)
- SSH key pair

## Quick Start (Azure — via deploy.sh)

> Each topology is a self-contained Terraform root module. Scripts run
> `terraform -chdir=topologies/<system>` directly — **never from the repo root**
> (the repo root only has the `local` provider and cannot initialize cloud providers).

```bash
cd viya4-iac-k8s

# Copy and customise the sample variables
cp topologies/azure/sample-input-azure.tfvars terraform.tfvars

# Authenticate (Service Principal)
export TF_VAR_azure_subscription_id="<subscription-id>"
export TF_VAR_azure_tenant_id="<tenant-id>"
export TF_VAR_azure_client_id="<client-id>"
export TF_VAR_azure_client_secret="<client-secret>"
export SYSTEM=azure

./scripts/deploy.sh apply setup install
```

`deployment_type` defaults to `"azure"` — no override needed unless running a different topology.

## Running a Topology Independently

Each topology module is **self-contained** (has its own `versions.tf` and provider block):

```bash
cd topologies/azure

cp sample-input-azure.tfvars terraform.tfvars
# fill in credentials as above

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Deployment Script

The `scripts/deploy.sh` helper handles the full lifecycle via the root dispatcher:

```bash
# Create infra + install Kubernetes
./scripts/deploy.sh apply setup install

# Tear down
./scripts/deploy.sh uninstall cleanup destroy
```

## Adding a New Deployment Type

See [ARCHITECTURE_DIAGRAMS.md](ARCHITECTURE_DIAGRAMS.md#adding-a-new-deployment-type).

## Variable Reference

| Variable | Default | Description |
|---|---|---|
| `deployment_type` | `"azure"` | Selects the topology module to activate |
| `prefix` | — | Naming prefix for all resources |
| `azure_resource_group` | — | Azure resource group (created by Terraform) |
| `azure_location` | — | Azure region (e.g. `eastus`) |
| `node_pools` | — | Map of Kubernetes node pools |
| `create_jump` | `false` | Whether to create a jump server |
| `create_nfs` | `false` | Whether to create an NFS server |

Full variable list: see [`variables.tf`](../variables.tf).

# Microsoft Azure — Cluster Creation Guide

This guide walks through creating a SAS Viya 4 Kubernetes cluster on Microsoft Azure
using `viya4-iac-k8s`.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Cluster Configuration](#cluster-configuration)
- [Execution](#execution)
- [Tear Down](#tear-down)

---

## Prerequisites

- An Azure subscription with sufficient quota for VMs, Public IPs, Load Balancers and disks.
- Azure credentials: either a service principal with enough RBAC (Contributor on the target resource group) or a VM with a managed identity that has equivalent permissions.
- Terraform and Ansible installed locally (or run using the provided Docker image).
- SSH keypair to access VMs (private key used by Ansible).

### Step 1 — Generate an SSH keypair

```bash
mkdir -p ~/.ssh/oss
ssh-keygen -t ed25519 -f ~/.ssh/oss/my-keypair -N "" -C "viya4-iac-k8s azure cluster"
chmod 700 ~/.ssh/oss
chmod 600 ~/.ssh/oss/my-keypair
chmod 644 ~/.ssh/oss/my-keypair.pub
```

Keep the private key locally; the public key will be injected into VMs by cloud-init.

### Step 2 — Create service principal (or use MSI)

Service principal (recommended for CI/manual runs):

```bash
az ad sp create-for-rbac --name "viya4-iac-k8s-<prefix>" --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>

# Note the output: use the appId, password, tenant
```

Or enable a managed identity on an Azure VM and set `azure_use_msi = true` in `terraform.tfvars`.

### Step 3 — Export credentials

Set environment variables (preferred) or use `TF_VAR_` variables. Example:

```bash
export AZURE_SUBSCRIPTION_ID=...
export AZURE_TENANT_ID=...
export AZURE_CLIENT_ID=...
export AZURE_CLIENT_SECRET=...
export SYSTEM=azure
```

If using managed identity, export `SYSTEM=azure` and set `azure_use_msi = true` in `terraform.tfvars`.

## Cluster Configuration

### Step 4 — Create `terraform.tfvars`

Copy the example and customize values:

```bash
cp examples/azure/sample-terraform-azure.tfvars terraform.tfvars
# Edit terraform.tfvars: prefix, azure_resource_group, azure_location, node_pools, cluster_vip_fqdn, etc.
```

If you prefer Terraform to create networking and LB resources, wire `modules/azure_network` and `modules/azure_api_lb` into `main.tf` (these modules exist but are not wired by default to avoid accidental network changes). Otherwise supply `azure_subnet_id` and `azure_nsg_id` for existing resources.

### DNS and Public IPs

If you use `modules/azure_api_lb`, Terraform will create Public IP(s) for the API and LoadBalancer. After `terraform apply` obtain the IPs (or after running the helper scripts) and register the following DNS records in your DNS zone:

- A record for `<prefix>-vip.<cluster_domain>` → API VIP (kube-vip)
- A record(s) for `<prefix>-lb.<cluster_domain>` → LoadBalancer addresses used by services/ingress

Ensure DNS resolves before running Ansible `setup install` so kubeconfig and TLS endpoints are valid.

## Execution

### Step 5 — Validate Terraform configuration

From the repo root:

```bash
terraform init -input=false -backend=false
terraform validate -var-file=examples/azure/sample-terraform-azure.tfvars -var 'deployment_type=azure'
```

### Step 6 — Plan (recommended)

```bash
terraform plan -var-file=examples/azure/sample-terraform-azure.tfvars -var 'deployment_type=azure'
```

### Step 7 — Apply + Ansible (provision + configure)

When ready to provision (this creates cloud resources and may incur cost):

```bash
export SYSTEM=azure
./oss-k8s.sh apply setup install
```

This runs Terraform `apply` then renders `ansible-vars.yaml` and runs the Ansible playbooks to bootstrap Kubernetes and deploy the Azure cloud-controller-manager components.

## Tear Down

To destroy everything created by Terraform (and avoid further charges):

```bash
export SYSTEM=azure
./oss-k8s.sh uninstall cleanup destroy
```

Notes
- Always run `terraform plan` before `apply` to review resource changes and charges.
- Ensure the service principal or managed identity has permission to create Public IPs, Load Balancers, VMs, disks and network resources in the target subscription/resource group.

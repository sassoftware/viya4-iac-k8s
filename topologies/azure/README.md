# SAS Viya 4 Infrastructure as Code (IaC) for Upstream Kubernetes on Microsoft Azure VMs

## Table of Contents

- [Overview](#overview)
- [Kubernetes Support](#kubernetes-support)
- [Prerequisites](#prerequisites)
  - [Technical Prerequisites](#technical-prerequisites)
  - [Terraform Requirements](#terraform-requirements)
  - [Ansible Requirements](#ansible-requirements)
  - [Docker Requirements](#docker-requirements)
- [Getting Started](#getting-started)
  - [Clone this Project](#clone-this-project)
  - [Authenticating Terraform to Access Microsoft Azure](#authenticating-terraform-to-access-microsoft-azure)
  - [Customizing Input Values](#customizing-input-values)
- [Creating and Managing the Cloud Resources](#creating-and-managing-the-cloud-resources)
  - [Deployment Script](#deployment-script)
  - [Docker Usage](#docker-usage)
- [Troubleshooting](#troubleshooting)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)
- [Additional Resources](#additional-resources)
  - [Azure Resources](#azure-resources)
  - [Terraform Resources](#terraform-resources)
  - [Kubernetes Resources](#kubernetes-resources)
- [Directory Structure](#directory-structure)
- [Variables Reference](#variables-reference)

---

## Overview

This project helps you to automate the cluster-provisioning phase of SAS Viya platform deployment on **Microsoft Azure virtual machines**. Unlike [viya4-iac-azure](https://github.com/sassoftware/viya4-iac-azure) which provisions a managed AKS cluster, this project provisions Azure infrastructure and then bootstraps an **open-source (upstream) Kubernetes** cluster on those VMs using Terraform and Ansible.

The repository uses a **topology-dispatcher model**: the root `main.tf` selects the active topology module based on the `deployment_type` variable (currently `"azure"`). Each topology under `topologies/` is self-contained and can also be run independently.

Here is a list of resources that this project can create:

> - Azure resource group
> - Virtual network, subnets (`k8s`, `misc`), network security groups, and NSG rules
> - Azure Standard Load Balancer (external) — stable public IP fronting all control-plane nodes on port 6443
> - Azure VMs for Kubernetes nodes — control plane and worker pools (with required labels and taints)
> - Infrastructure to deploy SAS Viya platform CAS in SMP or MPP mode
> - Jump server (bastion host)
> - NFS server for shared storage (LVM RAID across managed data disks)
> - Ansible `inventory` and `ansible-vars.yaml` files for subsequent cluster configuration

The Kubernetes cluster bootstrapped on these VMs includes:

> - Container Runtime Interface (CRI): [containerd](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)
> - Container Network Interface (CNI): [Calico](https://kubernetes.io/docs/concepts/cluster-administration/networking/#calico)
> - High-availability control plane VIP: [kube-vip](https://kube-vip.io/)
> - Azure Cloud Controller Manager (CCM) for native Azure LoadBalancer integration

See [docs/ARCHITECTURE_DIAGRAMS.md](../../docs/ARCHITECTURE_DIAGRAMS.md) for a detailed view of the repository layout and the Azure topology resource hierarchy.

This project addresses the first of three steps in the SAS Viya platform deployment process:

1. Provision resources.
2. Prepare for the deployment.
3. Customize and deploy the SAS Viya platform.

Once the cloud resources are provisioned, use the [viya4-deployment](https://github.com/sassoftware/viya4-deployment) project to deploy the SAS Viya platform in your cloud environment.

---

## Kubernetes Support

At this time, this project supports Kubernetes versions **1.32 through 1.35**.

---

## Prerequisites

Use of these tools requires operational knowledge of the following technologies:

- [Terraform](https://www.terraform.io/intro/index.html)
- [Ansible](https://docs.ansible.com/ansible/latest/user_guide/index.html#getting-started)
- [Docker](https://www.docker.com/)
- [Microsoft Azure Cloud](https://azure.microsoft.com/)
- [Kubernetes](https://kubernetes.io/docs/concepts/)

### Technical Prerequisites

This project supports two options for running the deployment:

- Using the `scripts/deploy.sh` deployment script on your local machine
- Using a Docker container to run all tooling (recommended)

Access to an **Azure Subscription** and an identity with the **Contributor** role are required. See [Authenticating Terraform to Access Microsoft Azure](#authenticating-terraform-to-access-microsoft-azure) for details.

### Terraform Requirements

- [Terraform](https://www.terraform.io/downloads.html) — >= 1.10.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure) — optional, useful for interactive authentication
- [jq](https://stedolan.github.io/jq/) — v1.6

### Ansible Requirements

- [ansible-core](https://docs.ansible.com/ansible/latest/installation_guide/index.html) — >= 2.15.13

### Docker Requirements

- [Docker](https://docs.docker.com/get-docker/)

---

## Getting Started

### Clone this Project

```bash
git clone https://github.com/sassoftware/viya4-iac-k8s
cd viya4-iac-k8s
```

### Authenticating Terraform to Access Microsoft Azure

The Terraform process manages Microsoft Azure resources on your behalf. In order to do so, it needs your Azure account information and a user identity with the required permissions.

The recommended approach is to pass credentials via environment variables so that secrets are never stored in version control:

```bash
export TF_VAR_azure_subscription_id="<subscription-id>"
export TF_VAR_azure_tenant_id="<tenant-id>"
export TF_VAR_azure_client_id="<client-id>"
export TF_VAR_azure_client_secret="<client-secret>"

# Also export ARM_* so Ansible picks them up for the Azure CCM DaemonSet
export ARM_SUBSCRIPTION_ID="$TF_VAR_azure_subscription_id"
export ARM_TENANT_ID="$TF_VAR_azure_tenant_id"
export ARM_CLIENT_ID="$TF_VAR_azure_client_id"
export ARM_CLIENT_SECRET="$TF_VAR_azure_client_secret"
```

Alternatively, if you are running from an Azure VM with a Managed Identity assigned, set:

```hcl
azure_use_msi = true
```

> `group_vars/all.yml` resolves `azure_client_id`, `azure_client_secret`,
> `azure_tenant_id`, and `azure_subscription_id` from `ARM_*` at Ansible runtime.
> These are passed to the Azure CCM DaemonSet and are **not** stored in
> `ansible-vars.yaml` or committed to source control.

### Customizing Input Values

Terraform scripts require variable definitions as input. Review and modify default values to meet your requirements. Create a file named `terraform-azure.tfvars` at the repo root to customize any input variable value.

Two example input files are provided under [`examples/`](examples/):

| File | Description |
|---|---|
| [`examples/sample-input-minimal.tfvars`](examples/sample-input-minimal.tfvars) | Minimal starter — control-plane + system + cas + generic worker pools |
| [`examples/sample-input.tfvars`](examples/sample-input.tfvars) | Full production — dedicated pools per SAS Viya workload class (cas, compute, stateless, stateful) |

Copy the example that best matches your deployment size:

```bash
# Minimal / evaluation deployment
cp topologies/azure/examples/sample-input-minimal.tfvars terraform-azure.tfvars

# Full production deployment with dedicated SAS Viya workload pools
cp topologies/azure/examples/sample-input.tfvars terraform-azure.tfvars
```

Edit `terraform-azure.tfvars` and fill in your required values. For the full variable reference, see the [Variables Reference](#variables-reference) section below or [`variables.tf`](variables.tf).

---

## Creating and Managing the Cloud Resources

### Deployment Script

Use the `scripts/deploy.sh` wrapper to handle the full Terraform + Ansible lifecycle:

```bash
export SYSTEM=azure
./scripts/deploy.sh apply setup install
```

| Stage | Duration | What Runs |
|---|---|---|
| `apply` | ~20 min | `terraform apply` — creates resource group, VNet, NSGs, VMs, Azure Standard LB, NFS server, jump host; writes `inventory` + `ansible-vars.yaml` |
| `setup` | ~15 min | `systems-install.yaml` — OS packages, sysctl, SSH keys, NFS LVM + exports, jump server config |
| `install` | ~25 min | `kubernetes-install.yaml` — full Azure kubeadm bootstrap with kube-vip, Calico CNI, Azure CCM |

You can run stages independently for re-runs:

```bash
./scripts/deploy.sh apply        # Terraform only
./scripts/deploy.sh setup        # OS baseline only
./scripts/deploy.sh install      # Kubernetes only (idempotent)
./scripts/deploy.sh uninstall    # kubeadm reset on all nodes
./scripts/deploy.sh destroy      # terraform destroy
```

### Docker Usage

Run the Docker container — no local Terraform or Ansible installation required. Build the image first:

```bash
docker build -t viya4-iac-k8s:latest .
```

Then run using an `azure.env` file containing your credentials (one `KEY=VALUE` per line, **no `export`**, **no quotes**):

```bash
# azure.env (keep this file outside the repo, never commit it)
TF_VAR_azure_subscription_id=<subscription-id>
TF_VAR_azure_tenant_id=<tenant-id>
TF_VAR_azure_client_id=<client-id>
TF_VAR_azure_client_secret=<client-secret>
ARM_SUBSCRIPTION_ID=<subscription-id>
ARM_TENANT_ID=<tenant-id>
ARM_CLIENT_ID=<client-id>
ARM_CLIENT_SECRET=<client-secret>
```

```bash
docker run --rm -it \
  --group-add root \
  --user root:root \
  --env SYSTEM=azure \
  --env IAC_TOOLING=docker \
  --env-file $HOME/azure.env \
  --volume $(pwd):/workspace \
  --volume $HOME/.ssh/oss:/root/.ssh/oss \
  viya4-iac-k8s:latest \
  apply setup install
```

---

## Troubleshooting

See the [Deployment Guide](../../docs/DEPLOYMENT_GUIDE.md) for common deployment patterns and troubleshooting information.

---

## Security

Additional configuration to harden your cluster environment is supported and encouraged. For example, you can restrict VM and cluster API access to specified IP address ranges using the `azure_default_public_access_cidrs`, `azure_vm_public_access_cidrs`, and `azure_cluster_endpoint_public_access_cidrs` variables.

**Important:** Never commit Azure credentials or secrets to version control. Use environment variables or an `azure.env` file (excluded via `.gitignore`) to supply sensitive values.

---

## Contributing

We welcome your contributions! Please open issues and pull requests via the project repository.

---

## License

This project is licensed under the [Apache 2.0 License](../../LICENSE).

---

## Additional Resources

### Azure Resources

- [Azure CLI](https://docs.microsoft.com/en-gb/cli/azure/?view=azure-cli-latest)
- [Terraform on Azure](https://docs.microsoft.com/en-us/azure/terraform)
- [Configure Terraform access to Azure](https://docs.microsoft.com/en-us/azure/terraform/terraform-install-configure)
- [Azure Virtual Machines](https://docs.microsoft.com/en-us/azure/virtual-machines/)
- [Azure Virtual Network](https://docs.microsoft.com/en-us/azure/virtual-network/)
- [Azure Active Directory (AD) & Service Principal (SP) concepts](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)

### Terraform Resources

- [Azure Provider](https://www.terraform.io/docs/providers/azurerm/index.html)
- [Azure Virtual Machine](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine)
- [Azure Virtual Network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)

### Kubernetes Resources

- [kubeadm — bootstrapping Kubernetes clusters](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Calico CNI](https://docs.tigera.io/calico/latest/about/)
- [containerd](https://containerd.io/)
- [kube-vip](https://kube-vip.io/)
- [Azure Cloud Controller Manager](https://github.com/kubernetes-sigs/cloud-provider-azure)

---

## Directory Structure

```
topologies/azure/
├── main.tf                       # Azure VMs, VNet, NSG, LB, public IPs
├── variables.tf                  # All input variables
├── locals.tf                     # Derived locals (node maps, naming)
├── outputs.tf                    # Cluster outputs (IPs, kube_api_endpoint)
├── versions.tf                   # Provider pins: azurerm ~>3.0, local ~>2.4
├── provider.tf                   # azurerm provider block
├── provider.tf.example           # Reference / override example
├── ansible.cfg                   # roles_path = ./roles:../../roles
├── requirements.txt              # Python dependencies (azure-sdk, ansible)
├── requirements.yml              # Ansible Galaxy collections
├── sample-input-azure.tfvars     # Legacy flat example (superseded by examples/)
│
├── examples/
│   ├── sample-input-minimal.tfvars  # Minimal starter (control-plane + system + cas + generic)
│   └── sample-input.tfvars          # Full production (dedicated per-workload pools)
│
├── group_vars/                   # Per-group SSH users & Azure credential lookup
│   ├── all.yml                   #   ARM_* env vars → azure_client_id/secret etc.
│   ├── k8s.yml                   #   ansible_user: azureuser (proxied via jump)
│   ├── jump.yml                  #   ansible_user: jumpuser  (direct SSH on public IP)
│   └── nfs.yml                   #   ansible_user: nfsuser   (proxied via jump)
│
├── inventories/
│   └── local                     # [local] localhost ansible_connection=local
│
├── modules/
│   ├── azure_api_lb/             # Azure Standard LB + public IP fronting control-plane (port 6443)
│   ├── azure_network/            # VNet, subnets, NSGs
│   └── azure_vm/                 # Azure VM instances (OS disk, data disks)
│
├── playbooks/
│   ├── kubernetes-install.yaml   # 11-stage Azure kubeadm bootstrap (see below)
│   ├── kubernetes-uninstall.yaml # kubeadm reset + resource cleanup
│   └── systems-install.yaml      # OS packages, SSH keys, NFS, jump setup
│
├── roles/
│   └── systems/                  # Topology-specific OS roles
│       ├── azure/init/           # No-op Azure init (VMs ready after cloud-init)
│       ├── common/               # Common OS prep (sysctl, packages)
│       ├── nfs_server/           # LVM + NFS export setup (Azure managed disks)
│       ├── jump_server/          # Jump server / bastion setup
│       └── ...
│
└── templates/
    ├── ansible-vars.yaml.tmpl    # Generated ansible-vars.yaml (rendered by Terraform)
    └── inventory.tmpl            # Generated Ansible inventory
```

> **Shared Kubernetes roles** live at `../../roles/kubernetes/` (repo root) and are
> automatically found via `roles_path = ./roles:../../roles` in `ansible.cfg`. This
> includes `kubeadm`, `cloud-provider`, `cni/calico`, `loadbalancer/kube_vip`,
> `storage/nfs-csi-driver`, `metrics-server`, and more.

---

## Variables Reference

| Variable | Required | Description |
|---|---|---|
| `deployment_type` | ✅ | Must be `"azure"` |
| `prefix` | ✅ | Cluster name prefix — used in all resource names |
| `azure_resource_group` | ✅ | Azure resource group name |
| `azure_location` | ✅ | Azure region (e.g. `eastus`, `westeurope`) |
| `ssh_public_key` | ✅ | Path to SSH public key file |
| `azure_subscription_id` | ✅* | Azure subscription ID (`TF_VAR_*` preferred) |
| `azure_tenant_id` | ✅* | Azure tenant ID (`TF_VAR_*` preferred) |
| `azure_client_id` | ✅* | Service principal app ID (`TF_VAR_*` preferred) |
| `azure_client_secret` | ✅* | Service principal secret (`TF_VAR_*` preferred) |
| `azure_use_msi` | — | Use Managed Identity instead of SP (default `false`) |
| `azure_vnet_address_space` | ✅ | CIDR for the entire VNet |
| `azure_subnets` | ✅ | Subnet map: `k8s` (nodes) and `misc` (jump/NFS) |
| `azure_default_public_access_cidrs` | ✅ | Allowed source CIDRs for SSH and API LB |
| `cluster_version` | ✅ | Kubernetes version (e.g. `"1.35.3"`) |
| `azure_ccm_version` | — | Azure CCM image tag — released independently of K8s (default `"1.33.1"`) |
| `cluster_api_internal_ip` | — | Static private IP for the Azure Internal Standard LB frontend. Used as `controlPlaneEndpoint` for in-cluster HA (avoids Azure LB hairpin). Default `"192.168.0.100"` |
| `cluster_vip_ip` | — | kube-vip VIP IP — static IP in the `misc` subnet not assigned to any VM. Leave empty to skip kube-vip |
| `cluster_vip_fqdn` | — | DNS name for the kube-vip VIP |
| `cluster_vip_version` | — | kube-vip version (default `"0.7.1"`) |
| `cluster_lb_addresses` | — | MetalLB / kube-vip address pool for `LoadBalancer` Services |
| `cluster_lb_type` | — | `kube_vip` or `metallb` for in-cluster service LB (default `"kube_vip"`). External API access always uses the Azure Standard LB |
| `node_pools` | ✅ | Node groups with `count`, `machine_type`, `os_disk`, `data_disks`, `node_taints`, `node_labels` |
| `create_jump` | — | Create a jump / bastion host (default `true`) |
| `create_nfs` | — | Create an NFS server VM (default `true`) |
| `nfs_data_disks` | — | List of NFS data disk sizes in GB — 3+ disks create RAID5 LVM (e.g. `[256,256,256,256]`) |

> ✅* — Required unless `azure_use_msi = true`. Set via `TF_VAR_*` or `ARM_*`
> environment variables rather than storing in `terraform-azure.tfvars`.

See [`examples/sample-input-minimal.tfvars`](examples/sample-input-minimal.tfvars) for a minimal starter example, or [`examples/sample-input.tfvars`](examples/sample-input.tfvars) for a full production example with dedicated SAS Viya workload pools.


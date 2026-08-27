# Azure Topology Architecture

[← Architecture Overview](overview.md) | [Deployment Guide →](../../topologies/azure/README.md)

## Resource Layout

```mermaid
graph TD
    SUB["Azure Subscription"]
    SUB --> RG["Resource Group
    azurerm_resource_group"]

    RG --> VNET["Virtual Network
    192.168.0.0/16 (default)"]

    VNET --> K8S_SN["Subnet: k8s
    192.168.0.0/23
    + NSG (k8s rules)"]
    VNET --> MISC_SN["Subnet: misc
    192.168.2.0/24
    + NSG (misc rules)"]

    K8S_SN --> LB_EXT["Azure Standard Load Balancer
    (external, public IP)
    port 6443 → control-plane nodes"]

    LB_EXT --> CP1["control-plane-1 VM"]
    LB_EXT --> CP2["control-plane-2 VM"]
    LB_EXT --> CP3["control-plane-3 VM"]

    K8S_SN --> WP["Worker VMs
    system · stateless · stateful
    cas · compute · singlestore"]

    MISC_SN --> JUMP["Jump Server VM
    (optional, create_jump=true)"]
    MISC_SN --> NFS["NFS Server VM
    (optional, create_nfs=true)
    LVM RAID over managed data disks"]
    MISC_SN --> CR["Container Registry VM
    Harbor
    (optional, create_cr=true)"]

    CP1 & CP2 & CP3 -->|etcd| ETCD[("etcd cluster")]
    CP1 & CP2 & CP3 --> CCM["Azure Cloud Controller Manager
    azure_ccm_version"]
```

## Networking Design

| Component | Detail |
| :--- | :--- |
| VNet | Created by Terraform, or attach to existing via `azure_vnet_name` |
| k8s subnet | All Kubernetes node NICs — control plane + workers |
| misc subnet | Jump, NFS, and container registry NICs |
| NSG rules | Auto-created (SSH, K8s API 6443, NodePort) unless `azure_create_nsg_rules = false` |
| Control-plane HA | Azure Standard Load Balancer (external) on port 6443 — **not kube-vip** |
| Service LB | kube-vip cloud provider or MetalLB — IP pool assigned via `cluster_lb_addresses` |
| Public IP | VMs optionally get public IPs (`azure_vm_public_ip_enabled`); restrict access via `azure_default_public_access_cidrs` |

## Authentication Options

```mermaid
flowchart LR
    TF["Terraform azurerm provider"]
    TF -->|"SP auth"| SP["Service Principal
    azure_client_id
    azure_client_secret
    azure_tenant_id"]
    TF -->|"MSI auth"| MSI["Managed Identity
    azure_use_msi = true
    (Azure VM only)"]
```

## Azure-Specific Components

| Component | Variable | Notes |
| :--- | :--- | :--- |
| Azure CCM | `azure_ccm_version` = `1.33.1` | Required for `kubernetes.io/role: master` node labelling and cloud routes |
| Accelerated Networking | `azure_accelerated_networking` = `true` | Requires supported VM SKU (D/E/F series) |
| NFS LVM RAID | `nfs_data_disks` = `[256, 256]` | Managed disks striped into a single LVM volume for higher throughput |

## Script Entry Point

```bash
# Azure uses deploy.sh (not oss-k8s.sh)
export AZURE_SUBSCRIPTION_ID=...
export AZURE_TENANT_ID=...
export AZURE_CLIENT_ID=...
export AZURE_CLIENT_SECRET=...

./scripts/deploy.sh apply    --system azure --workspace /workspace --tfvars /workspace/azure.tfvars
./scripts/deploy.sh install  --system azure --workspace /workspace
./scripts/deploy.sh destroy  --system azure --workspace /workspace
```

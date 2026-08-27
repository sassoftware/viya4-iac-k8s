# Architecture Overview — viya4-iac-k8s

This page describes the overall architecture of the `viya4-iac-k8s` multi-topology platform.
For topology-specific layouts see the linked pages below.

## Table of Contents

- [Repository Architecture](#repository-architecture)
- [Topology Dispatch Model](#topology-dispatch-model)
- [Ansible Role Resolution](#ansible-role-resolution)
- [Two-Stage Deployment Pipeline](#two-stage-deployment-pipeline)
- [Topology-Specific Architectures](#topology-specific-architectures)
- [Cluster Architecture (Common)](#cluster-architecture-common)
- [Runtime Workspace Isolation](#runtime-workspace-isolation)

---

## Repository Architecture

```mermaid
graph TD
    ROOT["viya4-iac-k8s (root)
    main.tf · locals.tf · variables.tf · versions.tf"]

    ROOT --> AZ["topologies/azure/
    azurerm provider
    Azure VMs + Networking"]
    ROOT --> OS["topologies/openstack/
    openstack provider
    Nova VMs + Neutron"]
    ROOT --> VS["topologies/vsphere/
    vsphere provider
    VM cloning"]
    ROOT --> BM["topologies/bare_metal/
    local provider only
    BYO hosts"]

    ROOT --> ROLES["roles/kubernetes/ (shared)
    cni · cri · control_plane
    node · vip · loadbalancer
    storage · metrics · toolbox"]

    AZ -->|"ansible_roles_path"| ROLES
    OS -->|"ansible_roles_path"| ROLES
    VS -->|"ansible_roles_path"| ROLES
    BM -->|"ansible_roles_path"| ROLES

    AZ --> SROLES_AZ["topologies/azure/roles/systems/azure/"]
    OS --> SROLES_OS["topologies/openstack/roles/systems/openstack/"]
    VS --> SROLES_VS["topologies/vsphere/roles/systems/vsphere/"]
    BM --> SROLES_BM["topologies/bare_metal/roles/systems/bare_metal/"]
```

---

## Topology Dispatch Model

The entry-point scripts bypass the root module and run Terraform directly inside the chosen topology directory. The root `main.tf` exists for reference and IDE navigation only.

```mermaid
flowchart LR
    U(["User runs\noss-k8s.sh / deploy.sh"])
    U --> DT{deployment_type}
    DT -->|azure| TF_AZ["terraform -chdir=topologies/azure"]
    DT -->|openstack| TF_OS["terraform -chdir=topologies/openstack"]
    DT -->|vsphere| TF_VS["terraform -chdir=topologies/vsphere"]
    DT -->|bare_metal| TF_BM["terraform -chdir=topologies/bare_metal"]

    TF_AZ --> INV["inventory + ansible-vars.yaml"]
    TF_OS --> INV
    TF_VS --> INV
    TF_BM --> INV

    INV --> ANS["Ansible Playbooks
    systems-install.yaml
    kubernetes-install.yaml"]
    ANS --> K8S(["Kubernetes Cluster"])
```

> **Note:** The bare metal `apply` phase is a no-op for VM provisioning. It only writes the inventory and `ansible-vars.yaml` files from existing host information.

---

## Ansible Role Resolution

Topology-specific OS roles and shared Kubernetes roles coexist via a dual `roles_path` in `ansible.cfg`:

```
roles_path = ./roles:../../roles
```

```mermaid
flowchart TD
    PLAY["Ansible Playbook"]

    PLAY -->|"1st lookup"| TSR["topologies/&lt;name&gt;/roles/
    systems/&lt;topology&gt;/
    (OS provisioning only)"]

    PLAY -->|"2nd lookup fallback"| SHARED["roles/kubernetes/
    cni · cri · control_plane
    node · storage · metrics
    loadbalancer · vip · toolbox"]

    TSR -->|"override if present"| SHARED
```

A topology can override any shared role by placing a same-named role in `topologies/<name>/roles/`. No changes to shared code are needed.

---

## Two-Stage Deployment Pipeline

```mermaid
sequenceDiagram
    participant U as Operator
    participant TF as Terraform
    participant AN as Ansible
    participant K8S as Kubernetes Cluster

    U->>TF: terraform apply (topology dir)
    Note over TF: Stage 1 — Infrastructure
    TF-->>TF: Provision VMs / validate hosts
    TF-->>U: inventory + ansible-vars.yaml

    U->>AN: ansible-playbook systems-install.yaml
    Note over AN: Stage 2a — OS Preparation
    AN-->>K8S: Install packages, configure OS, partition disks

    U->>AN: ansible-playbook kubernetes-install.yaml
    Note over AN: Stage 2b — Kubernetes Bootstrap
    AN-->>K8S: kubeadm init, CNI, CRI, kube-vip, storage, metrics
    K8S-->>U: kubeconfig
```

---

## Topology-Specific Architectures

| Topology | Infrastructure | Provisioning | Guide |
| :--- | :--- | :--- | :--- |
| **Azure** | Azure VMs, VNet, NSG, Load Balancer | Terraform (azurerm) | [azure.md](azure.md) |
| **OpenStack** | Nova VMs, Neutron networking, Floating IPs | Terraform (openstack) | [openstack.md](openstack.md) |
| **vSphere** | VM clones from template | Terraform (vsphere) | [vsphere.md](vsphere.md) |
| **Bare Metal** | Pre-existing hosts (BYO) | None — Ansible only | [bare-metal.md](bare-metal.md) |

---

## Cluster Architecture (Common)

All four topologies produce a Kubernetes cluster with this internal architecture:

[<img src="../images/viya4-iac-k8s-diag.png" alt="Cluster Architecture Diagram" width="750"/>](../images/viya4-iac-k8s-diag.png?raw=true)

```mermaid
graph TD
    VIP["Control Plane VIP
    kube-vip v0.7.1"]

    VIP --> CP1["control-plane-1"]
    VIP --> CP2["control-plane-2"]
    VIP --> CP3["control-plane-3"]

    CP1 & CP2 & CP3 -->|etcd cluster| ETCD[("etcd")]

    LB["Load Balancer
    kube-vip cloud provider
    or MetalLB"]

    LB --> WN1["stateless nodes"]
    LB --> WN2["stateful nodes"]
    LB --> WN3["cas nodes"]
    LB --> WN4["compute nodes"]
    LB --> WN5["system nodes"]

    CNI["Calico CNI v3.32.1
    NetworkPolicy + BGP"]
    CRI["containerd v2.2.2"]
    NFS["NFS Server
    default StorageClass"]
    LSP["local-storage
    StorageClass"]

    WN1 & WN2 & WN3 & WN4 --> CNI
    WN1 & WN2 & WN3 & WN4 --> CRI
    WN2 & WN3 --> LSP
    WN1 & WN2 --> NFS
```

**Kubernetes components installed on all topologies:**

| Component | Version | Purpose |
| :--- | :--- | :--- |
| kubeadm / kubelet / kubectl | per `cluster_version` | Cluster bootstrap and management |
| containerd | `2.2.2` | Container runtime |
| Calico | `3.32.1` | CNI — pod networking and NetworkPolicy |
| kube-vip | `0.7.1` | Control-plane virtual IP |
| kube-vip cloud provider | `v0.0.8` | Service LoadBalancer (kube-vip mode) |
| MetalLB | `0.14.3` | Service LoadBalancer (metallb mode) |
| NFS CSI Driver | `4.13.3` | Default storage class (NFS-backed) |
| sig-storage-local-static-provisioner | `2.8.0` | `local-storage` storage class |
| metrics-server | `3.13.0` | Pod/node resource metrics |
| Helm | `3.14.4` | Chart deployment |

---

## Runtime Workspace Isolation

Each cluster deployment is isolated in its own workspace directory. Multiple clusters can be deployed concurrently from the same bind-mounted workspace without state conflicts.

```
/workspace/
├── <prefix>-azure/
│   ├── terraform.tfvars      ← operator input
│   ├── terraform.tfstate     ← Terraform state
│   ├── inventory             ← generated
│   ├── ansible-vars.yaml     ← generated
│   ├── kubeconfig            ← generated post-install
│   └── logs/
│       ├── apply-<timestamp>.log
│       └── install-<timestamp>.log
│
├── <prefix>-openstack/       ← independent — safe to run in parallel
├── <prefix>-vsphere/
└── <prefix>-bare-metal/
```

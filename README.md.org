# SAS Viya 4 Infrastructure as Code — Upstream Kubernetes (Multi-Topology)

Automates provisioning and configuration of production-grade Kubernetes clusters
for SAS Viya 4 deployments across **OpenStack (HPOS)**, **VMware vSphere**,
**Microsoft Azure**, and **Bare Metal** environments.

---

## Repository Overview

This repository implements the **topology dispatcher pattern** — a single codebase
that supports four  platforms without any shared mutable state between them.

Each  platform lives in its own fully self-contained directory under `topologies/`
with its own Terraform provider, variables, Ansible playbooks, and OS-level roles.
A thin root `main.tf` acts as a dispatcher but is **not invoked by the scripts** —
both `deploy.sh` and `oss-k8s.sh` call `terraform -chdir=topologies/<system>` directly,
so only the active topology's provider is ever loaded or authenticated.

Shared Kubernetes bootstrap logic (kubeadm, CNI, storage, metrics) lives in
`roles/kubernetes/` at the repo root and is inherited by all topologies via the
dual `roles_path = ./roles:../../roles` setting in each topology's `ansible.cfg`.
A bug fix in a shared role automatically benefits all four topologies simultaneously.

| Topology | Cloud | Entry Point | Terraform Provisioning |
|---|---|---|---|
| `openstack` | OpenStack / HPOS | `scripts/oss-k8s.sh` | ✅ Nova VMs + Neutron networking |
| `vsphere` | VMware vSphere | `scripts/oss-k8s.sh` | ✅ vSphere VMs |
| `azure` | Microsoft Azure | `scripts/deploy.sh` | ✅ Azure VMs + VNet + NSG |
| `bare_metal` | Pre-existing VMs | `scripts/oss-k8s.sh` | ❌ Ansible-only (no Terraform) |

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Supported Topologies](#supported-topologies)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Cluster Creation Flow](#cluster-creation-flow)
- [What Gets Created](#what-gets-created)
- [Teardown](#teardown)
- [Docker Usage](#docker-usage)
- [Additional Documentation](#additional-documentation)

---

## Overview

This project automates the full lifecycle of a SAS Viya 4 Kubernetes cluster:

```
Credentials → terraform apply (VMs) → ansible setup (OS) → ansible install (K8s) → kubeconfig
```

| Phase | Tool | What It Does |
|---|---|---|
| `apply` | Terraform | Provisions VMs, disks, networks, generates `inventory` + `ansible-vars.yaml` |
| `setup` | Ansible | OS packages, sysctl, SSH keys, containerd, Helm |
| `install` | Ansible | kubeadm init, CNI (Calico), kube-vip, node join, kubeconfig fetch |

After `apply setup install` completes, a ready-to-use kubeconfig is written to the
workspace directory. Use it immediately with `kubectl`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       User                                  │
│                                                             │
│   scripts/deploy.sh          scripts/oss-k8s.sh             │
│   (SYSTEM=azure)             (SYSTEM=openstack /            │
│                               bare_metal / vsphere)         │
└──────────┬────────────────────────────┬─────────────────────┘
           │ terraform                  │ terraform
           │ -chdir=topologies/azure    │ -chdir=topologies/<SYSTEM>
           │                            │
           ▼                            ▼
    ┌──────────┐  ┌──────────┐  ┌─────────────┐  ┌──────────┐
    │  azure/  │  │openstack/│  │ bare_metal/ │  │ vsphere/ │
    │ topology │  │ topology │  │  topology   │  │ topology │
    │          │  │          │  │             │  │          │
    │ provider │  │ provider │  │  local      │  │ provider │
    │ azurerm  │  │openstack │  │  only       │  │ vsphere  │
    │          │  │          │  │             │  │          │
    │versions: │  │versions: │  │ versions:   │  │versions: │
    │azurerm + │  │openstack │  │ local only  │  │vsphere + │
    │local     │  │+ local   │  │             │  │local     │
    │          │  │          │  │             │  │          │
    │VM modules│  │VM modules│  │ inventory + │  │VM modules│
    │azure_net │  │openstack │  │ ansible-vars│  │vm/server │
    │azure_vm  │  │-vm       │  │ from IPs    │  │          │
    └────┬─────┘  └────┬─────┘  └──────┬──────┘  └────┬─────┘
         │             │               │               │
         └─────────────┴───────────────┴───────────────┘
                                │
                    ┌───────────▼────────────────────────┐
                    │   Ansible (per topology)           │
                    │                                    │
                    │  ANSIBLE_CONFIG →                  │
                    │    topologies/<topo>/ansible.cfg   │
                    │  (set at runtime by script /       │
                    │   entrypoint.sh, never baked in)   │
                    │                                    │
                    │  roles_path = ./roles:../../roles  │
                    │  │                                 │
                    │  ├── ./roles/systems/<topo>/       │
                    │  │     └── topology-specific       │
                    │  │         OS roles                │
                    │  └── ../../roles/kubernetes/       │
                    │        └── shared K8s bootstrap    │
                    │            roles (all topologies)  │
                    │                                    │
                    │  playbooks/                        │
                    │    systems-install.yaml            │
                    │    kubernetes-install.yaml         │
                    │    kubernetes-uninstall.yaml       │
                    └────────────────────────────────────┘
```

> **Note:** Root `main.tf` exists as an alternative entry point for direct
> `terraform apply` from the repo root, but is **not invoked by the scripts**.
> Scripts call `terraform -chdir=topologies/<system>` directly so only the
> active topology's provider is loaded and authenticated.

---

## Repository Structure

```
viya4-iac-k8s/
├── scripts/
│   ├── oss-k8s.sh              ← Orchestration: OpenStack / vSphere / bare metal
│   ├── deploy.sh               ← Orchestration: Azure
│   └── lib/
│       └── common.sh           ← Shared credential helpers (sourced by both scripts)
│
├── topologies/
│   ├── openstack/              ← OpenStack (HPOS) — Terraform + Ansible
│   │   ├── main.tf             ← OpenStack VM provisioning
│   │   ├── variables.tf        ← All input variables
│   │   ├── locals.tf           ← Derived values
│   │   ├── outputs.tf          ← Cluster outputs
│   │   ├── versions.tf         ← Provider requirements
│   │   ├── provider.tf.example ← Copy to provider.tf and fill in credentials
│   │   ├── ansible.cfg         ← Ansible config (roles_path includes shared roles)
│   │   ├── requirements.yml    ← Galaxy collections (topology-local copy)
│   │   ├── sample-input-openstack.tfvars
│   │   ├── modules/openstack-vm/   ← Nova instance + floating IP module
│   │   ├── playbooks/          ← kubernetes-install / uninstall / systems-install
│   │   ├── roles/systems/      ← OS-level Ansible roles
│   │   └── templates/          ← inventory.tmpl, ansible-vars.yaml.tmpl
│   │
│   ├── vsphere/                ← VMware vSphere — Terraform + Ansible
│   ├── azure/                  ← Microsoft Azure — Terraform + Ansible
│   └── bare_metal/             ← Physical/existing VMs — Ansible only
│
├── roles/
│   └── kubernetes/             ← Shared Kubernetes roles (all topologies)
│       ├── common/             ← Pre-flight checks, package installs
│       ├── control_plane/      ← kubeadm init, kube-vip, CNI
│       ├── node/               ← Worker node join
│       ├── storage/            ← NFS storage class
│       └── sas-iac-buildinfo/  ← Cluster build metadata ConfigMap
│
├── docker/
│   ├── Dockerfile              ← All tooling pre-installed (terraform, ansible, helm)
│   └── entrypoint.sh           ← Routes SYSTEM= to correct script
│
├── files/tools/                ← Helper scripts baked into Docker image
├── tests/                      ← Terraform variable validation tests
├── requirements.txt            ← Python deps: ansible-core, kubernetes, openshift
├── requirements.yml            ← Ansible Galaxy collections (single source of truth)
├── terraform.tfvars            ← YOUR cluster config (create from topology sample)
└── docs/
    ├── DEPLOYMENT_GUIDE.md     ← Full deployment reference
    └── ARCHITECTURE_DIAGRAMS.md
```

Each topology under `topologies/` is a **fully self-contained Terraform root module**
with its own `provider.tf`, `variables.tf`, `playbooks/`, and `roles/systems/`.
The shared `roles/kubernetes/` directory at the repo root is used by all topologies
via `roles_path = ./roles:../../roles` in each `ansible.cfg`.

---

## Supported Topologies

| Topology | Script | Terraform Dir | VMs Provisioned |
|---|---|---|---|
| `openstack` | `scripts/oss-k8s.sh` | `topologies/openstack/` | ✅ OpenStack Nova + Neutron |
| `vsphere` | `scripts/oss-k8s.sh` | `topologies/vsphere/` | ✅ VMware vSphere |
| `azure` | `scripts/deploy.sh` | `topologies/azure/` | ✅ Azure VMs |
| `bare_metal` | `scripts/oss-k8s.sh` | _(none — Ansible only)_ | ❌ Pre-existing machines |

---

## Prerequisites

### Tooling

| Tool | Minimum Version |
|---|---|
| Terraform | ≥ 1.10.0 |
| Python 3 | ≥ 3.8 |
| ansible-core | 2.16.4 (via `requirements.txt`) |
| OpenStack CLI | latest (OpenStack topology only) |

Install all Python + Ansible dependencies:
```bash
pip install -r requirements.txt
ansible-galaxy collection install -r requirements.yml
```

### SSH Keypair

Ansible uses SSH key auth to connect to all cluster nodes. Generate a dedicated keypair:

```bash
mkdir -p ~/.ssh/oss
ssh-keygen -t ed25519 -f ~/.ssh/oss/my-keypair -N "" -C "viya4-iac-k8s"
chmod 700 ~/.ssh/oss && chmod 600 ~/.ssh/oss/my-keypair
```

Upload `~/.ssh/oss/my-keypair.pub` to your cloud platform, then set
`openstack_ssh_keypair` (or `control_plane_ssh_key_name`) in `terraform.tfvars`
to match the uploaded keypair name.

---

## Quick Start

### Step 1 — Copy the sample tfvars for your topology

```bash
# OpenStack
cp topologies/openstack/sample-input-openstack.tfvars terraform.tfvars

# vSphere
cp topologies/vsphere/sample-input-vsphere.tfvars terraform.tfvars

# Azure
cp topologies/azure/sample-input-azure.tfvars terraform.tfvars

# Bare Metal
cp topologies/bare_metal/sample-input-bare-metal.tfvars terraform.tfvars
```

### Step 2 — Edit terraform.tfvars

Set at minimum:
- `prefix` — cluster name prefix (cluster becomes `<prefix>-oss`)
- `deployment_type` — `"openstack"`, `"vsphere"`, `"azure"`, or `"bare_metal"`
- Cloud-specific settings (image, keypair, network, flavors/sizes)
- `node_pools` — count and flavor for each workload class

See the topology README for the full variable reference.

### Step 3 — Set credentials and run

```bash
# OpenStack
export $(grep -v '^#' ~/.openstack_creds.env | grep -v '^$' | xargs)
export SYSTEM=openstack
./scripts/oss-k8s.sh apply setup install

# vSphere
export VSPHERE_SERVER=vcenter.example.com VSPHERE_USER=admin VSPHERE_PASSWORD=xxx
export SYSTEM=vsphere
./scripts/oss-k8s.sh apply setup install

# Azure
export ARM_SUBSCRIPTION_ID=... ARM_TENANT_ID=... ARM_CLIENT_ID=... ARM_CLIENT_SECRET=...
export SYSTEM=azure
./scripts/deploy.sh apply setup install

# Bare Metal (no apply step)
export SYSTEM=bare_metal ANSIBLE_USER=rocky
./scripts/oss-k8s.sh setup install
```

---

## Cluster Creation Flow

```
oss-k8s.sh apply setup install
       │
       ├─── apply ──────────────────────────────────────────────────────────────┐
       │      │                                                                 │
       │      ├─ [openstack only] allocate_vip_floating_ip                     │
       │      │    └─ openstack floating ip create  (idempotent)              │
       │      ├─ terraform -chdir=topologies/<SYSTEM> init                     │
       │      ├─ terraform -chdir=topologies/<SYSTEM> apply                   │
       │      │    └─ Creates: VMs, disks, security groups, inventory,        │
       │      │                ansible-vars.yaml                               │
       │      ├─ sleep 60  (OS boot time)                                     │
       │      └─ [openstack only] patch_vip_allowed_pairs                     │
       │           └─ Neutron PUT /ports/{id} allowed_address_pairs           │
       │                                                                       │
       ├─── setup ──────────────────────────────────────────────────────────────┤
       │      │                                                                 │
       │      ├─ pip install -r requirements.txt                               │
       │      ├─ ansible-galaxy collection install -r requirements.yml        │
       │      └─ ansible-playbook systems-install.yaml                        │
       │           └─ roles/systems: packages, sysctl, SSH keys, containerd  │
       │                                                                       │
       └─── install ────────────────────────────────────────────────────────────┘
              │
              ├─ [openstack only] patch_vip_allowed_pairs  (idempotent re-run)
              ├─ pip install -r requirements.txt
              ├─ ansible-galaxy collection install -r requirements.yml
              └─ ansible-playbook kubernetes-install.yaml
                   └─ roles/kubernetes:
                        common/      → container runtime, kubeadm, kubelet
                        control_plane/init/primary   → kubeadm init + kube-vip
                        control_plane/init/secondary → control plane join
                        node/init    → worker node join
                        cni/         → Calico CNI install
                        storage/     → NFS storage class
                        sas-iac-buildinfo/ → ConfigMap with deployment metadata
```

---

## What Gets Created

| File | Location | Description |
|---|---|---|
| `terraform.tfstate` | repo root | Terraform state — keep safe, back up |
| `inventory` | repo root | Ansible inventory (node IPs + groups) |
| `ansible-vars.yaml` | repo root | Ansible variables passed to all playbooks |
| `<prefix>-oss-kubeconfig.conf` | repo root | Cluster admin kubeconfig |

Access the cluster:
```bash
export KUBECONFIG=$(pwd)/<prefix>-oss-kubeconfig.conf
kubectl get nodes -o wide
```

---

## Teardown

```bash
export SYSTEM=openstack   # or vsphere / azure
./scripts/oss-k8s.sh uninstall destroy
```

- `uninstall` — runs `kubernetes-uninstall.yaml`, removes kubeadm state from all nodes
- `destroy` — runs `terraform destroy`, deletes all cloud resources, removes state files

> You will be prompted to confirm (`yes`) before `destroy` proceeds.

---

## Docker Usage

The Docker image has all tooling pre-installed (Terraform, Ansible, Helm, kubectl,
OpenStack CLI). Mount your workspace directory containing `terraform.tfvars`:

```bash
# Build
docker build -t viya4-iac-k8s -f docker/Dockerfile .

# Run (OpenStack example)
docker run --rm \
  -e SYSTEM=openstack \
  --env-file ~/.openstack_creds.env \
  -v $(pwd):/workspace \
  viya4-iac-k8s apply setup install
```

The entrypoint automatically routes `SYSTEM=azure` to `deploy.sh` and all other
values to `oss-k8s.sh`. All files (`terraform.tfvars`, `terraform.tfstate`,
`inventory`, `ansible-vars.yaml`, kubeconfig) are read from and written to
`/workspace`.

---

## Additional Documentation

| Document | Description |
|---|---|
| [`topologies/openstack/README.md`](topologies/openstack/README.md) | OpenStack (HPOS) — full step-by-step guide |
| [`topologies/vsphere/README.md`](topologies/vsphere/README.md) | VMware vSphere — full step-by-step guide |
| [`topologies/azure/README.md`](topologies/azure/README.md) | Azure — full step-by-step guide |
| [`topologies/bare_metal/README.md`](topologies/bare_metal/README.md) | Bare metal — full step-by-step guide |
| [`docs/DEPLOYMENT_GUIDE.md`](docs/DEPLOYMENT_GUIDE.md) | Detailed deployment reference |
| [`docs/ARCHITECTURE_DIAGRAMS.md`](docs/ARCHITECTURE_DIAGRAMS.md) | Architecture diagrams |

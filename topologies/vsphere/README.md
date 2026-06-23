# VMware vSphere Topology

Step-by-step guide to provisioning a SAS Viya 4 Kubernetes cluster on
VMware vSphere / vCenter infrastructure.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
  - [Step 1 — Prepare a VM Template](#step-1--prepare-a-vm-template)
  - [Step 2 — Generate SSH Keypair](#step-2--generate-ssh-keypair)
  - [Step 3 — Set vSphere Credentials](#step-3--set-vsphere-credentials)
- [Cluster Configuration](#cluster-configuration)
  - [Step 4 — Create terraform.tfvars](#step-4--create-terraformtfvars)
- [Cluster Creation](#cluster-creation)
  - [Step 5 — Provision and Install](#step-5--provision-and-install)
  - [Step 6 — Verify the Cluster](#step-6--verify-the-cluster)
- [Teardown](#teardown)
- [Variables Reference](#variables-reference)

---

## Directory Structure

```
topologies/vsphere/
├── main.tf                      # vSphere VM cloning + file provisioning
├── variables.tf                 # All input variables
├── locals.tf                    # Derived locals (cluster_name, node maps)
├── outputs.tf                   # Cluster outputs
├── versions.tf                  # Provider pins: vsphere ~>2.6, local ~>2.4
├── provider.tf.example          # Copy → provider.tf for standalone use
├── ansible.cfg                  # roles_path = ./roles:../../roles
├── requirements.yml             # Ansible Galaxy collections
├── sample-input-vsphere.tfvars  # Example terraform.tfvars
│
├── modules/
│   ├── vm/                      # vSphere VM module (compute + storage)
│   └── server/                  # vSphere server module (PostgreSQL nodes)
│
├── playbooks/
│   ├── kubernetes-install.yaml
│   ├── kubernetes-uninstall.yaml
│   └── systems-install.yaml
│
├── roles/
│   └── systems/                 # OS-level roles (vSphere-specific)
│
└── templates/
    ├── ansible-vars.yaml.tmpl
    └── inventory.tmpl
```

---

## Prerequisites

### Step 1 — Prepare a VM Template

Your vCenter must have a VM template cloneable by Terraform. The template must:
- Run **Ubuntu 22.04 LTS** or **Rocky Linux 8/9**
- Have `open-vm-tools` installed
- Have `cloud-init` or a default user with `sudo` (no password) configured
- Have SSH enabled

Minimum node specifications:

| Role | vCPU | RAM | Disk |
|---|---|---|---|
| Control Plane | 8 | 32 GB | 100 GB |
| System / Worker | 8 | 16 GB | 100 GB |
| Jump Server | 4 | 8 GB | 100 GB |
| NFS Server | 4 | 8 GB | 400 GB |

---

### Step 2 — Generate SSH Keypair

```bash
mkdir -p ~/.ssh/oss
ssh-keygen -t ed25519 -f ~/.ssh/oss/vsphere-key -N "" -C "viya4-iac-k8s-vsphere"
chmod 700 ~/.ssh/oss && chmod 600 ~/.ssh/oss/vsphere-key
```

Set `system_ssh_keys_dir = "/root/.ssh/oss"` in `terraform.tfvars` — Terraform
copies all `.pub` files from this directory into each VM's `authorized_keys`.

---

### Step 3 — Set vSphere Credentials

Export credentials as environment variables before running the script:

```bash
export VSPHERE_SERVER=vcenter.example.com
export VSPHERE_USER=administrator@vsphere.local
export VSPHERE_PASSWORD=<your-vcenter-password>
export SYSTEM=vsphere
export ANSIBLE_USER=ubuntu     # or rocky — must match the template OS user
```

> The script reads `VSPHERE_SERVER`, `VSPHERE_USER`, `VSPHERE_PASSWORD` and passes
> them as `TF_VAR_vsphere_*` to Terraform automatically.

---

## Cluster Configuration

### Step 4 — Create terraform.tfvars

Copy the sample to the **repo root**:

```bash
cp topologies/vsphere/sample-input-vsphere.tfvars terraform.tfvars
```

Edit the required values:

```hcl
deployment_type = "vsphere"
prefix          = "mycluster"

# vSphere connection (can also be set via VSPHERE_* env vars)
vsphere_server        = "vcenter.example.com"
vsphere_user          = "administrator@vsphere.local"
vsphere_datacenter    = "DC1"
vsphere_datastore     = "datastore1"
vsphere_resource_pool = "SAS-Viya"
vsphere_folder        = "SAS-Clusters"
vsphere_template      = "ubuntu2204-template"
vsphere_network       = "VM Network"

# Static networking for all VMs
gateway     = "192.168.1.1"
netmask     = "24"
dns_servers = ["192.168.1.53"]

# SSH keys distributed to all nodes
system_ssh_keys_dir = "/root/.ssh/oss"
ansible_user        = "ubuntu"
ansible_password    = ""

# Cluster
cluster_domain         = "vsphere.example.com"
cluster_vip_version    = "0.8.7"
cluster_vip_ip         = "192.168.1.100"     # Pre-assigned static IP for kube-vip
cluster_vip_fqdn       = "mycluster-vip.vsphere.example.com"
cluster_lb_type        = "kube_vip"
cluster_lb_addresses   = ["range-global: 192.168.1.101-192.168.1.110"]
control_plane_ssh_key_name = "cp_ssh"

# Node pools — ip_addresses[] pins static IPs; count uses DHCP
node_pools = {
  control_plane = {
    count        = 3
    ip_addresses = ["192.168.1.10", "192.168.1.11", "192.168.1.12"]
    cpus         = 8
    memory       = 32768
    os_disk      = 100
    misc_disks   = []
    node_taints  = []
    node_labels  = {}
  }
  system = {
    count        = 3
    ip_addresses = ["192.168.1.20", "192.168.1.21", "192.168.1.22"]
    cpus         = 8
    memory       = 16384
    os_disk      = 100
    misc_disks   = []
    node_taints  = []
    node_labels  = { "workload.sas.com/class" = "system" }
  }
}

create_jump = true
jump_ip     = "192.168.1.5"
create_nfs  = true
nfs_ip      = "192.168.1.6"
```

---

## Cluster Creation

### Step 5 — Provision and Install

```bash
cd /path/to/viya4-iac-k8s
export VSPHERE_SERVER=vcenter.example.com
export VSPHERE_USER=administrator@vsphere.local
export VSPHERE_PASSWORD=<password>
export SYSTEM=vsphere

./scripts/oss-k8s.sh apply setup install
```

| Stage | Duration | What Runs |
|---|---|---|
| `apply` | ~15 min | `terraform apply` — clones VMs from template, assigns static IPs, writes `inventory` + `ansible-vars.yaml` |
| `setup` | ~15 min | `systems-install.yaml` — OS packages, sysctl, SSH keys, containerd, kubelet |
| `install` | ~20 min | `kubernetes-install.yaml` — kubeadm init, kube-vip, Calico CNI, worker joins, kubeconfig |

---

### Step 6 — Verify the Cluster

```bash
export KUBECONFIG=$(pwd)/<prefix>-oss-kubeconfig.conf
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

---

## Teardown

```bash
export SYSTEM=vsphere
./scripts/oss-k8s.sh uninstall destroy
```

> You will be prompted to confirm (`yes`) before `destroy` proceeds.

---

## Variables Reference

| Variable | Required | Description |
|---|---|---|
| `deployment_type` | ✅ | Must be `"vsphere"` |
| `prefix` | ✅ | Cluster name prefix |
| `vsphere_server` | ✅ | vCenter hostname or IP |
| `vsphere_user` | ✅ | vCenter username |
| `vsphere_password` | ✅ | vCenter password |
| `vsphere_datacenter` | ✅ | vSphere datacenter name |
| `vsphere_datastore` | ✅ | Datastore for VM disks |
| `vsphere_resource_pool` | ✅ | Resource pool for VMs |
| `vsphere_template` | ✅ | VM template to clone |
| `vsphere_network` | ✅ | Network portgroup name |
| `gateway` | ✅ | Default gateway for all VMs |
| `netmask` | ✅ | CIDR prefix length (e.g. `24`) |
| `dns_servers` | ✅ | List of DNS server IPs |
| `cluster_vip_ip` | ✅ | Static IP for kube-vip HA VIP |
| `cluster_vip_fqdn` | ✅ | DNS name for the VIP |
| `node_pools` | ✅ | Node groups with count, IPs, CPU, memory, disk |
| `system_ssh_keys_dir` | ✅ | Absolute path to `.pub` key directory |
| `create_jump` / `jump_ip` | — | Jump server config |
| `create_nfs` / `nfs_ip` | — | NFS server config |
| `postgres_servers` | — | Internal PostgreSQL instances |

See [`sample-input-vsphere.tfvars`](sample-input-vsphere.tfvars) for a fully
annotated example.

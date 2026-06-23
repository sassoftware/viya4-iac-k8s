# Bare Metal (BYO Host) Topology

Step-by-step guide to installing a SAS Viya 4 Kubernetes cluster on
pre-existing physical or virtual machines.

> **No Terraform.** The `apply` and `destroy` actions are no-ops for this topology.
> You bring the machines; this tool handles OS preparation, Kubernetes installation,
> and day-two operations.

## Table of Contents

- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
  - [Step 1 — Verify Host Requirements](#step-1--verify-host-requirements)
  - [Step 2 — Generate and Distribute SSH Keys](#step-2--generate-and-distribute-ssh-keys)
  - [Step 3 — Set Ansible Credentials](#step-3--set-ansible-credentials)
- [Cluster Configuration](#cluster-configuration)
  - [Step 4 — Create inventory](#step-4--create-inventory)
  - [Step 5 — Create ansible-vars.yaml](#step-5--create-ansible-varsyaml)
- [Cluster Installation](#cluster-installation)
  - [Step 6 — Run Setup and Install](#step-6--run-setup-and-install)
  - [Step 7 — Verify the Cluster](#step-7--verify-the-cluster)
- [Teardown](#teardown)
- [Variables Reference](#variables-reference)

---

## Directory Structure

```
topologies/bare_metal/
├── main.tf                        # Minimal: writes inventory + ansible-vars.yaml only
├── variables.tf                   # Topology input variables
├── locals.tf                      # Derived values
├── outputs.tf                     # Cluster outputs
├── versions.tf                    # Provider pin: local ~>2.4
├── provider.tf.example            # Reference only — no remote provider needed
├── ansible.cfg                    # roles_path = ./roles:../../roles
├── requirements.yml               # Ansible Galaxy collections
├── sample-ansible-vars.yaml       # Annotated example ansible-vars.yaml
├── sample-inventory               # Annotated example inventory file
├── sample-input-bare-metal.tfvars # Example terraform.tfvars (optional)
│
├── playbooks/
│   ├── kubernetes-install.yaml
│   ├── kubernetes-uninstall.yaml
│   └── systems-install.yaml
│
├── roles/
│   └── systems/                   # OS-level roles (common packages, sysctl)
│
└── templates/
    ├── ansible-vars.yaml.tmpl
    └── inventory.tmpl
```

---

## Prerequisites

### Step 1 — Verify Host Requirements

All machines must be accessible from the machine running this tool via SSH.

**Minimum specifications per node role:**

| Role | Count | vCPU | RAM | Disk |
|---|---|---|---|---|
| Control Plane | 1 or 3 | 8 | 32 GB | 100 GB |
| System Worker | ≥ 1 | 8 | 16 GB | 100 GB |
| Jump Server | 0 or 1 | 4 | 8 GB | 50 GB |
| NFS Server | 0 or 1 | 4 | 8 GB | 400 GB |

**Supported operating systems:**
- Rocky Linux 8 / 9
- Ubuntu 22.04 LTS / 24.04 LTS

**Requirements on each host:**
- Static or stable DHCP-assigned IP addresses
- SSH accessible from the orchestrator machine
- `sudo` without a tty password (add to `/etc/sudoers`: `<user> ALL=(ALL) NOPASSWD:ALL`)
- Ports 22, 6443, 2379-2380, 10250-10252 open between nodes

---

### Step 2 — Generate and Distribute SSH Keys

```bash
mkdir -p ~/.ssh/oss
ssh-keygen -t ed25519 -f ~/.ssh/oss/bm-key -N "" -C "viya4-iac-k8s-bm"
chmod 700 ~/.ssh/oss && chmod 600 ~/.ssh/oss/bm-key

# Copy public key to every node
for HOST in 10.0.0.10 10.0.0.11 10.0.0.20 10.0.0.30 10.0.0.5 10.0.0.6; do
  ssh-copy-id -i ~/.ssh/oss/bm-key.pub rocky@$HOST
done
```

---

### Step 3 — Set Ansible Credentials

```bash
export SYSTEM=bare_metal
export ANSIBLE_USER=rocky           # OS user on all nodes
export ANSIBLE_PASSWORD=""          # Leave empty if SSH key auth is used
export ANSIBLE_SSH_KEY=/root/.ssh/oss/bm-key
```

> You can alternatively set `TF_VAR_ansible_user`, `TF_VAR_ansible_password`,
> and `TF_VAR_ansible_ssh_private_key` in your shell.

---

## Cluster Configuration

### Step 4 — Create inventory

The inventory file maps hostnames to node groups. Copy the sample and edit:

```bash
cp topologies/bare_metal/sample-inventory inventory
```

**Example inventory:**

```ini
[oss_cluster:children]
oss_control_plane
oss_workers
oss_jump
oss_nfs

[oss_control_plane]
cp1 ansible_host=10.0.0.10

[oss_workers]
sys1 ansible_host=10.0.0.20  node_role=system
wrkr1 ansible_host=10.0.0.21 node_role=stateless
cas1 ansible_host=10.0.0.22  node_role=cas
mgmt1 ansible_host=10.0.0.23 node_role=compute

[oss_jump]
jump ansible_host=10.0.0.5

[oss_nfs]
nfs ansible_host=10.0.0.6
```

For a HA control plane (3 nodes), add them with the `oss_control_plane` group and add:

```ini
[oss_vip]
vip ansible_host=10.0.0.100     # kube-vip address — must be routable but not assigned to a NIC
```

---

### Step 5 — Create ansible-vars.yaml

Copy the sample and edit:

```bash
cp topologies/bare_metal/sample-ansible-vars.yaml ansible-vars.yaml
```

**Key fields:**

```yaml
cluster_name: mycluster
cluster_domain: bare.example.com
cluster_vip_ip: 10.0.0.100              # HA VIP (or single-CP node IP)
cluster_vip_fqdn: mycluster-vip.bare.example.com
cluster_vip_version: "0.8.7"

ansible_user: rocky
ansible_password: ""
ansible_ssh_private_key_file: /root/.ssh/oss/bm-key

nfs_private_ip: 10.0.0.6
jump_private_ip: 10.0.0.5

kube_vip_cloud_controller: true
cluster_lb_addresses:
  - range-global: 10.0.0.101-10.0.0.110

# NFS server path
nfs_server: 10.0.0.6
nfs_path: /export

# Jump server
jump_rwx_filestore_endpoint:   ""
jump_rwx_filestore_path:       ""
```

See [`sample-ansible-vars.yaml`](sample-ansible-vars.yaml) for the full annotated
reference.

---

## Cluster Installation

### Step 6 — Run Setup and Install

> For bare metal the `apply` action is a no-op (machines already exist) and
> `destroy` only runs the Ansible uninstall.

```bash
cd /path/to/viya4-iac-k8s
export SYSTEM=bare_metal

./scripts/oss-k8s.sh setup install
```

| Stage | Duration | What Runs |
|---|---|---|
| `setup` | ~15 min | `systems-install.yaml` — packages, sysctl, SSH keys, containerd, kubelet |
| `install` | ~20 min | `kubernetes-install.yaml` — kubeadm init, kube-vip, Calico CNI, worker joins |

> If machines already have Ansible prerequisites met, you can skip `setup` and run
> only `./scripts/oss-k8s.sh install`.

---

### Step 7 — Verify the Cluster

```bash
export KUBECONFIG=$(pwd)/<cluster_name>-oss-kubeconfig.conf
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

---

## Teardown

Bare metal teardown only runs the Kubernetes uninstall playbook. Machines are
**not** deleted.

```bash
export SYSTEM=bare_metal
./scripts/oss-k8s.sh uninstall
```

This runs `kubernetes-uninstall.yaml` which performs `kubeadm reset`, removes CNI
configs, and resets iptables on all nodes.

---

## Variables Reference

Because bare metal has no Terraform-managed infrastructure, most parameters are
set directly in `ansible-vars.yaml` rather than `terraform.tfvars`.

| Parameter | File | Description |
|---|---|---|
| `cluster_name` | ansible-vars.yaml | Short cluster identifier |
| `cluster_domain` | ansible-vars.yaml | DNS domain for the cluster |
| `cluster_vip_ip` | ansible-vars.yaml | kube-vip HA address (or single-CP IP) |
| `cluster_vip_fqdn` | ansible-vars.yaml | DNS FQDN resolving to the VIP |
| `cluster_vip_version` | ansible-vars.yaml | kube-vip container image tag |
| `ansible_user` | ansible-vars.yaml | OS user on all cluster nodes |
| `ansible_ssh_private_key_file` | ansible-vars.yaml | Path to SSH private key |
| `nfs_private_ip` | ansible-vars.yaml | IP of the NFS server |
| `jump_private_ip` | ansible-vars.yaml | IP of the jump / access server |
| `cluster_lb_addresses` | ansible-vars.yaml | MetalLB or kube-vip cloud LB address pools |

See [`sample-inventory`](sample-inventory) and
[`sample-ansible-vars.yaml`](sample-ansible-vars.yaml) for fully annotated examples.

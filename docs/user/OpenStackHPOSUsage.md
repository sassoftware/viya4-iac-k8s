# OpenStack HPOS Environment — Cluster Creation Guide

This guide walks through creating a SAS Viya 4 Kubernetes cluster on an OpenStack
HPOS (HPC/Private OpenStack) environment using `viya4-iac-k8s`.

## Table of Contents

- [Prerequisites](#prerequisites)
  - [Step 1 — Generate an SSH Keypair](#step-1--generate-an-ssh-keypair)
  - [Step 2 — Upload the Public Key to OpenStack](#step-2--upload-the-public-key-to-openstack)
  - [Step 3 — Create the OpenStack Credentials File](#step-3--create-the-openstack-credentials-file)
  - [Step 4 — Source the Credentials File](#step-4--source-the-credentials-file)
  - [Step 5 — Install the OpenStack CLI](#step-5--install-the-openstack-cli)
  - [Step 6 — Allocate Floating IPs for the Cluster VIP and Load Balancer](#step-6--allocate-floating-ips-for-the-cluster-vip-and-load-balancer)
- [Cluster Configuration](#cluster-configuration)
  - [Step 7 — Create terraform.tfvars](#step-7--create-terraformtfvars)
- [Execution](#execution)
  - [Step 8 — Provision and Install](#step-8--provision-and-install)
  - [Step 9 — Verify the Cluster](#step-9--verify-the-cluster)
- [Tear Down](#tear-down)

---

## Prerequisites

### Step 1 — Generate an SSH Keypair

This keypair is used by Ansible to push authorized keys to all cluster nodes.

```bash
# Create the directory
mkdir -p ~/.ssh/oss

# Generate the keypair
ssh-keygen -t ed25519 -f ~/.ssh/oss/cluster_access -N "" -C "viya4-iac-k8s cluster"

# Set correct permissions
chmod 700 ~/.ssh/oss
chmod 600 ~/.ssh/oss/cluster_access
chmod 644 ~/.ssh/oss/cluster_access.pub

# Verify
ls -la ~/.ssh/oss/
# cluster_access      (private key)
# cluster_access.pub  (public key)
```

---

### Step 2 — Upload the Public Key to OpenStack

1. Log in to your OpenStack dashboard (e.g. `https://dashboard.hpos5.rnd.sas.com`)
2. Navigate to **Project → Compute → Key Pairs**
3. Click **Import Public Key**
4. Fill in the form:
   - **Key Pair Name**: `terraform-test-key` ← this must match `openstack_ssh_keypair` in your `terraform.tfvars`
   - **Key Type**: `SSH Key`
   - **Public Key**: paste the contents of `~/.ssh/oss/cluster_access.pub`
     ```bash
     cat ~/.ssh/oss/cluster_access.pub
     ```
5. Click **Import Key Pair**

---

### Step 3 — Create the OpenStack Credentials File

Create `.openstack_creds.env` **outside the repo** with your tenant credentials.

> ⚠️ Do **NOT** quote values. No trailing spaces.

```bash
cat > ~/.openstack_creds.env << 'EOF'
# OpenStack Keystone endpoint
OS_AUTH_URL=https://dashboard.hpos5.rnd.sas.com:5000/v3/

# OpenStack credentials
OS_USERNAME=<your_openstack_username>
OS_PASSWORD=<your_openstack_password>

# OpenStack project / tenant
OS_PROJECT_NAME=<your_project_name>

# OpenStack domain
OS_USER_DOMAIN_NAME=<your_domain>        # e.g. Default or sas-ldap

# OpenStack region (leave empty if single-region)
OS_REGION_NAME=

# Ansible SSH credentials for cluster nodes
TF_VAR_ansible_user=<vm_os_user>         # e.g. admin or ubuntu
TF_VAR_ansible_password=<vm_os_password>
EOF

# Protect the file
chmod 600 ~/.openstack_creds.env
```

---

### Step 4 — Source the Credentials File

```bash
source ~/.openstack_creds.env
export SYSTEM=openstack
```

> `oss-k8s.sh` will also auto-source `~/.openstack_creds.env` at runtime if
> `$OS_AUTH_URL` is not already set, but sourcing it manually first is recommended
> so that the OpenStack CLI commands in the next steps work correctly.

---

### Step 5 — Install the OpenStack CLI

The `allocate-vip.sh` script and `patch_vip_allowed_pairs` function in `oss-k8s.sh`
require the `openstack` CLI client.

```bash
pip install python-openstackclient
```

Verify:

```bash
openstack --insecure token issue
```

---

### Step 6 — Allocate Floating IPs for the Cluster VIP and Load Balancer

Before configuring `terraform.tfvars`, you need two floating IPs reserved on your
tenant network:

1. **`cluster_vip_ip`** — the kube-vip control-plane HA endpoint (API server VIP)
2. **`cluster_lb_addresses`** — the kube-vip cloud-provider LoadBalancer service VIP (used by Viya ingress)

Run the helper script from the repo root:

```bash
cd /path/to/viya4-iac-k8s

# Ensure openstack_network_name is already set in terraform.tfvars (see Step 7),
# or set it temporarily before running:
./allocate-vip.sh
```

The script will:
- Allocate two floating IPs from your tenant network
- Automatically write `cluster_vip_ip` and `cluster_lb_addresses` into `terraform.tfvars`
- Print the next-step instructions

Example output:
```
[cluster_vip_ip]      = "10.119.129.26"
[cluster_lb_addresses] = "range-global: 10.119.129.63-10.119.129.63"
```

**After running `allocate-vip.sh`, you must:**

1. Register both IPs in DNS (`names.sas.com`, `unx.sas.com` domain):
   ```
   A    <prefix>-vip.unx.sas.com   →  <cluster_vip_ip>
   PTR  <cluster_vip_ip>           →  <prefix>-vip.unx.sas.com
   A    <prefix>-lb.unx.sas.com    →  <lb_vip>
   PTR  <lb_vip>                   →  <prefix>-lb.unx.sas.com
   ```
2. Set `cluster_vip_fqdn` in `terraform.tfvars` to the registered FQDN:
   ```hcl
   cluster_vip_fqdn = "<prefix>-vip.unx.sas.com"
   ```
3. Verify DNS is live before proceeding:
   ```bash
   nslookup <prefix>-vip.unx.sas.com
   nslookup <prefix>-lb.unx.sas.com
   ```

---

## Cluster Configuration

### Step 7 — Create terraform.tfvars

Copy the example file into the repo root:

```bash
cd /path/to/viya4-iac-k8s
cp examples/openstack/sample-terraform-static-ips.tfvars terraform.tfvars
```

Open `terraform.tfvars` and update the required values:

```hcl
# General
prefix           = "mycluster"   # ← CHANGE: cluster name becomes mycluster-oss
ansible_user     = "admin"
ansible_password = "admin"

# OpenStack settings
openstack_domain_name       = "sas-ldap"
openstack_network_name      = "provider"
openstack_image_name        = "rocky96"           # ← CHANGE: your Glance image name
openstack_ssh_keypair       = "terraform-test-key" # ← must match Step 2
openstack_availability_zone = "nova-11"            # ← CHANGE: your AZ
openstack_flavor_defaults   = "np.8x16x250"        # ← CHANGE: your default flavor
openstack_floating_ip_pool  = null                 # null = no floating IPs (static mode)
openstack_insecure          = true

# Kubernetes
cluster_version     = "1.35.3"   # Latest supported: 1.32.x – 1.35.x
cluster_cri_version = "1.7.28"
cluster_domain      = "example.sas.com"   # ← CHANGE

# VIP — populated by allocate-vip.sh (Step 6)
cluster_vip_version = "0.7.1"
cluster_vip_ip      = "10.119.129.26"                    # ← from Step 6
cluster_vip_fqdn    = "mycluster-vip.unx.sas.com"        # ← from Step 6 DNS registration

# Load Balancer — populated by allocate-vip.sh (Step 6)
cluster_lb_type      = "kube_vip"
cluster_lb_addresses = ["range-global: 10.119.129.63-10.119.129.63"]  # ← from Step 6

# Node pools
# REQUIRED: control_plane and system keys must always be present.
# Add additional pools for workload classes as needed.
node_pools = {
  control_plane = {          # REQUIRED – DO NOT RENAME
    count       = 3          # Always odd for HA (3 recommended minimum)
    flavor      = "np.8x32x150"
    os_disk     = 100
    node_taints = []
    node_labels = {}
  },
  system = {                 # REQUIRED – DO NOT RENAME
    count       = 1
    flavor      = "np.8x16x250"
    os_disk     = 100
    node_taints = []
    node_labels = { "kubernetes.azure.com/mode" = "system" }
  },
  cas = {
    count      = 3
    flavor     = "np.8x16x250"
    os_disk    = 350
    misc_disks = [150, 150]  # Extra data volumes for CAS
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = { "workload.sas.com/class" = "cas" }
  },
  compute = {
    count       = 1
    flavor      = "np.8x16x250"
    os_disk     = 100
    node_taints = ["workload.sas.com/class=compute:NoSchedule"]
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  },
  stateful = {
    count      = 2
    flavor     = "np.8x16x250"
    os_disk    = 100
    misc_disks = [150]
    node_taints = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = { "workload.sas.com/class" = "stateful" }
  },
  stateless = {
    count       = 4
    flavor      = "np.8x16x250"
    os_disk     = 100
    node_taints = ["workload.sas.com/class=stateless:NoSchedule"]
    node_labels = { "workload.sas.com/class" = "stateless" }
  }
}

# Optional auxiliary servers
create_jump = true
jump_ip     = null   # null = DHCP-assigned; actual IP visible in Terraform output

create_nfs = true
nfs_ip     = null

# Optional: external PostgreSQL (omit to use internal)
# postgres_servers = { default = { server_disk_size = 128, server_version = 15, server_ssl = "off" } }
```

> **Note on `deployment_type`**: Do **not** set `deployment_type` in `terraform.tfvars`.
> It is injected automatically by `oss-k8s.sh` via `export SYSTEM=openstack`.

---

## Execution

### Step 8 — Provision and Install

```bash
cd /path/to/viya4-iac-k8s

export SYSTEM=openstack

# Full cluster provisioning in one command:
./oss-k8s.sh apply setup install
```

| Sub-command | What it does |
|---|---|
| `apply`   | Runs `terraform apply` — creates VMs on OpenStack |
| `setup`   | Runs Ansible `systems-install.yaml` — configures the OS on all nodes |
| `install` | Runs Ansible `kubernetes-install.yaml` — installs Kubernetes via kubeadm |

> After `apply` completes, `oss-k8s.sh` automatically calls `patch_vip_allowed_pairs()`
> which uses the Neutron API to add `cluster_vip_ip` and `cluster_lb_addresses` to
> `allowed_address_pairs` on all control-plane ports. This is required because most
> OpenStack environments block setting `allowed_address_pairs` at port-creation time.

---

### Step 9 — Verify the Cluster

After a successful run, a kubeconfig file is generated in the repo root:

```bash
export KUBECONFIG=$(ls *-oss-kubeconfig.conf | head -1)
kubectl get nodes -o wide
```

All nodes should show `Ready` status. Example:

```
NAME                          STATUS   ROLES           AGE   VERSION
mycluster-oss-control-plane   Ready    control-plane   10m   v1.35.3
mycluster-oss-system-01       Ready    <none>          8m    v1.35.3
mycluster-oss-cas-01          Ready    <none>          8m    v1.35.3
```

---

## Tear Down

```bash
export SYSTEM=openstack
./oss-k8s.sh uninstall cleanup destroy
```

| Sub-command | What it does |
|---|---|
| `uninstall` | Runs Ansible `kubernetes-uninstall.yaml` — removes Kubernetes from all nodes |
| `cleanup`   | Cleans up system-level software and configuration |
| `destroy`   | Runs `terraform destroy` — deletes all OpenStack VMs, volumes, and ports |

> The destroy step requires confirmation (`y/yes`) when run natively outside Docker.

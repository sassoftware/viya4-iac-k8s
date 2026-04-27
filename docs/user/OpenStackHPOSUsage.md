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
  - [Step 8 — Build the Docker Image (optional)](#step-8--build-the-docker-image-optional)
  - [Step 9 — Provision and Install](#step-9--provision-and-install)
  - [Step 10 — Verify the Cluster](#step-10--verify-the-cluster)
- [Install SAS Viya (DAC)](#install-sas-viya-dac)
  - [Step 11 — Prepare the DAC ansible-vars.yaml](#step-11--prepare-the-dac-ansible-varsyaml)
  - [Step 12 — Run DAC](#step-12--run-dac)
- [Tear Down](#tear-down)

---

## Prerequisites

### Step 1 — Generate an SSH Keypair

This keypair is injected by OpenStack into every VM at creation time and used by
Ansible to SSH into all cluster nodes during `setup install`.

Choose a keypair name (e.g. `my-keypair`) — you will use this **same name** in
Step 2 (OpenStack upload) and in `openstack_ssh_keypair` in `terraform.tfvars`.

```bash
# Create the directory
mkdir -p ~/.ssh/oss

# Generate the keypair — replace 'my-keypair' with your chosen name
ssh-keygen -t ed25519 -f ~/.ssh/oss/my-keypair -N "" -C "viya4-iac-k8s cluster"

# Set correct permissions
chmod 700 ~/.ssh/oss
chmod 600 ~/.ssh/oss/my-keypair
chmod 644 ~/.ssh/oss/my-keypair.pub

# Verify
ls -la ~/.ssh/oss/
# my-keypair      (private key)  ← used by Ansible via ansible_ssh_private_key_file
# my-keypair.pub  (public key)   ← uploaded to OpenStack in Step 2
```

---

### Step 2 — Upload the Public Key to OpenStack

Upload the public key you generated in Step 1 to OpenStack so it gets injected
into every VM at creation time.

1. Log in to your OpenStack dashboard (e.g. `https://dashboard.<your-openstack-host>`)
2. Navigate to **Project → Compute → Key Pairs**
3. Click **Import Public Key**
4. Fill in the form:
   - **Key Pair Name**: `my-keypair` ← use the same name you chose in Step 1
   - **Key Type**: `SSH Key`
   - **Public Key**: paste the output of:
     ```bash
     cat ~/.ssh/oss/my-keypair.pub
     ```
5. Click **Import Key Pair**

> The keypair name you enter here must exactly match `openstack_ssh_keypair`
> in `terraform.tfvars` (Step 7) and the private key filename in `~/.ssh/oss/`.

---

### Step 3 — Create the OpenStack Credentials File

Create `.openstack_creds.env` **outside the repo** with your tenant credentials.

> ⚠️ Do **NOT** quote values. No trailing spaces.
>
> ⚠️ Do **NOT** add `export` to any line in this file.
> - For your **shell** (Step 4), the `export $(...)` wrapper handles exporting.
> - For **Docker** `--env-file`, the `export` keyword causes a fatal error:
>   `docker: poorly formatted environment: variable 'export OS_AUTH_URL' contains whitespaces.`

```bash
cat > ~/.openstack_creds.env << 'EOF'
# OpenStack Keystone endpoint
# Full v3 endpoint URL including port 5000 and /v3/ path
# e.g. https://dashboard.<your-openstack-host>:5000/v3/
OS_AUTH_URL=https://<your-openstack-auth-url>:5000/v3/

# OpenStack credentials
OS_USERNAME=<your_openstack_username>
OS_PASSWORD=<your_openstack_password>

# OpenStack project / tenant
OS_PROJECT_NAME=<your_project_name>

# Identity domain for your USER account.
# Use 'Default' for standard OpenStack, 'sas-ldap' for HPOS/SAS LDAP environments.
OS_USER_DOMAIN_NAME=sas-ldap

# Identity domain for your PROJECT (tenant).
# Required for OpenStack Identity v3. Usually the same value as OS_USER_DOMAIN_NAME.
# Omitting this causes: "Expecting to find domain in project" (HTTP 400).
OS_PROJECT_DOMAIN_NAME=sas-ldap

# OpenStack region (leave empty if single-region)
OS_REGION_NAME=

# OS-level SSH credentials Ansible uses to connect to provisioned VMs.
# These are NOT your OpenStack API credentials.
# TF_VAR_ansible_user     — VM OS username created by cloud-init.
#                           Use 'rocky' for Rocky Linux images (e.g. rocky96),
#                           'ubuntu' for Ubuntu images.
# TF_VAR_ansible_password — VM OS sudo password set by cloud-init on the VM.
TF_VAR_ansible_user=rocky
TF_VAR_ansible_password=admin
EOF

# Protect the file
chmod 600 ~/.openstack_creds.env
```

---

### Step 4 — Source the Credentials File

```bash
# Works in both bash and ksh
export $(grep -v '^#' ~/.openstack_creds.env | grep -v '^$' | xargs)
export SYSTEM=openstack
```

> **Shell note:** `source ~/.openstack_creds.env` works in **bash** but may not
> export variables correctly in **ksh**. The `export $(...)` form above works
> reliably in both shells.

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

> **PATH note:** When installing with `pip` (without `sudo`), the `openstack` binary
> is placed in `~/.local/bin/` which may **not** be in your `$PATH` by default.
> If `openstack: command not found` after install, fix it with one of the following:
>
> **Option 1 — Add `~/.local/bin` to your PATH (recommended):**
> ```bash
> echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
> source ~/.bashrc
> ```
>
> **Option 2 — Install system-wide (requires sudo):**
> ```bash
> sudo pip install python-openstackclient
> ```
>
> **Option 3 — Copy binary manually (quick fix):**
> ```bash
> sudo cp ~/.local/bin/openstack /usr/local/bin/
> ```

Verify the CLI is working and can authenticate:

```bash
openstack --insecure token issue
```

> **Note:** If you get `Expecting to find domain in project (HTTP 400)`, ensure
> `OS_PROJECT_DOMAIN_NAME` is set in `~/.openstack_creds.env` (see Step 4).
> This is a required field for OpenStack Identity v3 and is often the same value
> as `OS_USER_DOMAIN_NAME` (e.g. `sas-ldap` for HPOS environments).

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

1. Register both IPs in your DNS zone (the value of `cluster_domain` in `terraform.tfvars`):
   ```
   A    <prefix>-vip.<your-dns-zone>   →  <cluster_vip_ip>
   PTR  <cluster_vip_ip>              →  <prefix>-vip.<your-dns-zone>
   A    <prefix>-lb.<your-dns-zone>    →  <lb_vip>
   PTR  <lb_vip>                      →  <prefix>-lb.<your-dns-zone>
   ```
   > `<your-dns-zone>` is the DNS domain for your OpenStack project/tenant
   > (e.g. `myproject.openstack.example.com`). Contact your OpenStack
   > or network administrator to register the records.
2. Set `cluster_vip_fqdn` in `terraform.tfvars` to the registered FQDN:
   ```hcl
   cluster_vip_fqdn = "<prefix>-vip.<your-dns-zone>"
   ```
3. Verify DNS is live before proceeding:
   ```bash
   nslookup <prefix>-vip.<your-dns-zone>
   nslookup <prefix>-lb.<your-dns-zone>
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
openstack_ssh_keypair       = "my-keypair"          # ← must match Step 2 (keypair name uploaded to OpenStack)
system_ssh_keys_dir         = "/root/.ssh/oss"      # ← absolute path; tilde (~) does not expand inside Docker
openstack_availability_zone = "nova-11"            # ← CHANGE: your AZ
openstack_flavor_defaults   = "np.8x16x250"        # ← CHANGE: your default flavor
openstack_floating_ip_pool  = null                 # null = no floating IPs (static mode)
openstack_insecure          = true

# Kubernetes
cluster_version     = "1.34.6"   # Latest supported: 1.32.x – 1.35.x
cluster_cri_version = "2.2.2"
cluster_domain      = "<your-dns-zone>"   # ← CHANGE: your tenant DNS domain, e.g. myproject.openstack.example.com

# VIP — populated by allocate-vip.sh (Step 6)
cluster_vip_version = "0.7.1"
cluster_vip_ip      = "10.119.129.26"                              # ← from Step 6
cluster_vip_fqdn    = "<prefix>-vip.<your-dns-zone>"              # ← from Step 6 DNS registration

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

### Step 8 — Build the Docker Image (optional)

If you prefer to run `oss-k8s.sh` inside Docker (recommended for reproducibility),
build the image first from the repo root:

```bash
cd /path/to/viya4-iac-k8s
docker build -t viya4-iac-k8s:latest .
```

> Skip this step if running `oss-k8s.sh` natively.

---

### Step 9 — Provision and Install

#### Option A — Native

> **Prerequisites (native only):** `oss-k8s.sh` calls `ansible-galaxy` and installs
> Python packages via `pip` automatically during `setup` and `install`. You need:
> - `ansible-core` installed and on your `PATH`:
>   ```bash
>   sudo dnf install -y ansible-core   # Rocky / RHEL 9
>   # OR
>   sudo apt-get install -y ansible-core  # Ubuntu 22.04/24.04
>   ```
> - Python 3 + pip available (standard on Rocky 9 / Ubuntu 22.04+).
>   The `oss-k8s.sh` script automatically runs
>   `python3 -m pip install --user -r requirements.txt`
>   before each Ansible playbook, which installs `kubernetes`, `openshift`,
>   `dnspython`, and `jmespath` — the Python libraries required by `kubernetes.core`
>   Ansible modules.

```bash
cd /path/to/viya4-iac-k8s

source $HOME/.openstack_creds.env
export SYSTEM=openstack

# Full cluster provisioning in one command:
./oss-k8s.sh apply setup install
```

#### Option B — Docker

```bash
cd /path/to/viya4-iac-k8s

docker run --rm -it \
  --network host \
  --group-add root \
  --user root:root \
  --env SYSTEM=openstack \
  --env IAC_TOOLING=docker \
  --env-file $HOME/.openstack_creds.env \
  --volume $(pwd):/workspace \
  --volume /root/.ssh/oss:/root/.ssh/oss:ro \
  viya4-iac-k8s:latest apply setup install
```

> **Docker notes:**
> - `--user root:root` is required so that `~/.ssh/oss` resolves correctly to
>   `/root/.ssh/oss` inside the container. Using `$(id -u):$(id -g)` will cause
>   SSH key path resolution to fail.
> - `--volume /root/.ssh/oss:/root/.ssh/oss:ro` mounts your SSH keys into the
>   container at the same absolute path used by `system_ssh_keys_dir` in `terraform.tfvars`.
>   This is **required** — Ansible reads the private key from this path during `setup install`.
> - `--network host` is **required** for OpenStack environments on private/corporate networks.
>   Without it, Docker uses bridge networking (NAT) and the container cannot reach internal
>   OpenStack endpoints (Keystone, Neutron, Nova). The symptom is `patch_vip_allowed_pairs:
>   could not obtain Keystone token or Neutron URL, skipping.` immediately after `apply`.
> - `--env-file` injects all `OS_*` and `TF_VAR_*` credentials automatically.
>   Do **not** include `export` in this file — see Step 3.
> - `--volume $(pwd):/workspace` mounts your local directory so `terraform.tfvars`,
>   `terraform.tfstate`, `inventory`, and `ansible-vars.yaml` are written back to your host.

| Sub-command | What it does |
|---|---|
| `apply`   | Runs `terraform apply` — creates VMs on OpenStack |
| `setup`   | Runs Ansible `systems-install.yaml` — configures the OS on all nodes |
| `install` | Runs Ansible `kubernetes-install.yaml` — installs Kubernetes via kubeadm |

> After `apply` completes, `oss-k8s.sh` automatically calls `patch_vip_allowed_pairs()`
> which uses the Neutron API to add `cluster_vip_ip` and `cluster_lb_addresses` to
> `allowed_address_pairs` on all control-plane ports. This is required because most
> OpenStack environments block setting `allowed_address_pairs` at port-creation time.
>
> ⚠️ **If you see `patch_vip_allowed_pairs: could not obtain Keystone token or Neutron URL, skipping.`**
> this is **not harmless** — the VIP port patch is skipped and kube-vip will be unable to
> bind the control-plane VIP (OpenStack port security will block the traffic). The `install`
> step will fail with unreachable control-plane errors.
>
> **Root cause:** The function authenticates to Keystone using `OS_AUTH_URL`, `OS_USERNAME`,
> `OS_PASSWORD`, `OS_USER_DOMAIN_NAME`, `OS_PROJECT_NAME`, and `OS_PROJECT_DOMAIN_NAME`.
> All six must be set correctly in your environment. The most common cause of the skip is
> a missing or wrong `OS_PROJECT_DOMAIN_NAME` — see Step 3.

---

### Step 10 — Verify the Cluster

After a successful run, a kubeconfig file is generated in the repo root
(or `/workspace` if using Docker):

```bash
# Native
export KUBECONFIG=$(ls *-oss-kubeconfig.conf | head -1)

# Docker (file is in the mounted workspace directory)
export KUBECONFIG=$(pwd)/$(ls *-oss-kubeconfig.conf | head -1)

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

## Install SAS Viya (DAC)

After the cluster is up and verified, use `viya4-deployment` (DAC) to install SAS Viya.

### Step 11 — Prepare the DAC ansible-vars.yaml

Create or edit `ansible-vars.yaml` in your `viya4-deployment` directory. The following
fields are critical for HPOS/OpenStack:

```yaml
# Jump server — DAC tunnels through this to reach internal cluster nodes
JUMP_SVR_USER: "rocky"                          # must match ansible_user in terraform.tfvars
JUMP_SVR_PRIVATE_KEY: "/config/jump_svr_private_key"  # fixed container path — do not change

# Kubeconfig — DAC uses this to talk to the cluster
KUBECONFIG: "/config/kubeconfig"                # fixed container path — do not change
```

> ⚠️ `JUMP_SVR_PRIVATE_KEY` and `KUBECONFIG` are **container-internal paths** — these
> are the mount targets used in the `docker run` command below. Do not change these values.

### Step 12 — Run DAC

The kubeconfig is generated by `setup install` as `<prefix>-oss-kubeconfig.conf`
in your `viya4-iac-k8s` workspace directory. It must be explicitly mounted into
the DAC container — DAC does not auto-discover it for OSS clusters.

```bash
# Replace paths and prefix with your actual values
IAC_DIR=/path/to/viya4-iac-k8s
DAC_DIR=/path/to/viya4-deployment
PREFIX=mycluster    # must match 'prefix' in terraform.tfvars

# Step 1 — baseline install (storage classes, ingress, etc.)
docker run --rm \
  --group-add root \
  --user root:root \
  --volume ${DAC_DIR}:/data \
  --volume ${DAC_DIR}/ansible-vars.yaml:/config/config \
  --volume ${IAC_DIR}/terraform.tfstate:/config/tfstate \
  --volume ${IAC_DIR}/${PREFIX}-oss-kubeconfig.conf:/config/kubeconfig \
  --volume /root/.ssh/oss/cluster_access:/config/jump_svr_private_key \
  viya4-deployment:latest \
  --tags "baseline,install"

# Step 2 — viya install
docker run --rm \
  --group-add root \
  --user root:root \
  --volume ${DAC_DIR}:/data \
  --volume ${DAC_DIR}/ansible-vars.yaml:/config/config \
  --volume ${IAC_DIR}/terraform.tfstate:/config/tfstate \
  --volume ${IAC_DIR}/${PREFIX}-oss-kubeconfig.conf:/config/kubeconfig \
  --volume /root/.ssh/oss/cluster_access:/config/jump_svr_private_key \
  viya4-deployment:latest \
  --tags "viya,install"
```

> **Key mount notes:**
> | Mount | Purpose |
> |---|---|
> | `${PREFIX}-oss-kubeconfig.conf:/config/kubeconfig` | **Required** — DAC does not auto-discover OSS kubeconfig |
> | `cluster_access:/config/jump_svr_private_key` | SSH key for DAC to tunnel through jump server — use `cluster_access`, NOT `my-keypair` |
> | `terraform.tfstate:/config/tfstate` | Provides jump/NFS server IPs to DAC |

> **Why `cluster_access` and not `my-keypair`?**
> - `my-keypair` — injected by OpenStack into VMs at creation; used by Ansible (`oss-k8s.sh`) to SSH in during `setup install`
> - `cluster_access` — a secondary key pushed to all VMs by Ansible during `setup`; used by DAC to SSH through the jump server

---

#### Option A — Native

```bash
export SYSTEM=openstack
./oss-k8s.sh uninstall cleanup destroy
```

#### Option B — Docker

```bash
docker run --rm -it \
  --network host \
  --group-add root \
  --user root:root \
  --env SYSTEM=openstack \
  --env IAC_TOOLING=docker \
  --env-file $HOME/.openstack_creds.env \
  --volume $(pwd):/workspace \
  --volume /root/.ssh/oss:/root/.ssh/oss:ro \
  viya4-iac-k8s:latest uninstall cleanup destroy
```

| Sub-command | What it does |
|---|---|
| `uninstall` | Runs Ansible `kubernetes-uninstall.yaml` — removes Kubernetes from all nodes |
| `cleanup`   | Cleans up system-level software and configuration |
| `destroy`   | Runs `terraform destroy` — deletes all OpenStack VMs, volumes, and ports |

> The destroy step requires confirmation (`y/yes`) when run natively outside Docker.

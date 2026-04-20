# GitHub Copilot Instructions — viya4-iac-k8s

## Project Purpose
Automates provisioning of open-source Kubernetes clusters for SAS Viya 4 deployments on **bare metal**, **VMware vSphere/vCenter**, or **OpenStack** (including HPOS). Two-stage pipeline: Terraform provisions VMs (vSphere/OpenStack only), then Ansible configures the OS and installs Kubernetes via kubeadm.

## Architecture Overview
- **`oss-k8s.sh`** — single entry point; orchestrates Terraform + Ansible. Rewrites `provider.tf` and surgically strips `main.tf` at runtime before every Terraform invocation.
- **Terraform** (`*.tf` at root + `modules/`) — provisions infrastructure. Modules: `modules/openstack-vm/` (OpenStack), `modules/vm/` + `modules/server/` (vSphere), `modules/noop/` (cross-platform stub). For bare metal, only generates `inventory` and `ansible-vars.yaml`; no VMs created.
- **Ansible** (`playbooks/`, `roles/`) — called by `oss-k8s.sh` with generated `inventory` and `ansible-vars.yaml` (both rendered from `templates/ansible/` via `local_file` Terraform resources).
- **Data flow**: `terraform apply` → renders `inventory` + `ansible-vars.yaml` → `ansible-playbook` consumes them.
- **Playbook execution order**: `systems-install.yaml` (OS prep, NFS, jump, PostgreSQL, container registry) → `kubernetes-install.yaml` (CRI → common → VIP primary → control-plane init → CNI → secondary CPs → worker nodes → load balancer → labels/taints → storage).

## `SYSTEM` / `deployment_type` Is the Master Switch
Every conditional in `main.tf`, `locals.tf`, and `oss-k8s.sh` keys off this value.
- Set via env var: `export SYSTEM=openstack` (or `vsphere` / `bare_metal`). Default: `bare_metal`.
- Passed to Terraform as `-var "deployment_type=$SYSTEM"`.
- **Never set `deployment_type` in `terraform.tfvars`** — use `SYSTEM=` so `oss-k8s.sh` also rewrites `provider.tf` and `main.tf` correctly.

## Runtime File Mutation (Critical)
`oss-k8s.sh` mutates tracked files before every Terraform run — do not hand-edit them:
- **`provider.tf`** — replaced wholesale with the provider block for the active `SYSTEM`. Committed baseline is the OpenStack form (used for CI linting).
- **`main.tf`** — `awk` strips the opposite platform's module blocks; backup kept at `.main.tf.iac-backup`, restored on `EXIT` trap. A `runtime-provider-stubs.tf` is generated to satisfy vSphere module references during OpenStack runs (using `modules/noop/` as a no-op stub).

## Key Developer Workflows

### Full lifecycle (native)
```bash
export SYSTEM=openstack   # or vsphere / bare_metal
# OpenStack: source ~/.openstack_creds.env  (OS_* vars auto-mapped to TF_VAR_openstack_*)
./oss-k8s.sh apply setup install        # provision → OS setup → K8s install
./oss-k8s.sh uninstall cleanup destroy  # tear down
```

### Docker (recommended for reproducibility)
```bash
docker run --rm -it \
  --group-add root --user $(id -u):$(id -g) \
  --env SYSTEM=openstack --env IAC_TOOLING=docker \
  --env-file $HOME/.openstack_creds.env \
  --volume $(pwd):/workspace \
  viya4-iac-k8s:latest apply setup install
```
In Docker mode `WORKDIR=/workspace` (mounted volume) and `BASEDIR=/viya4-iac-k8s` (baked image). `terraform.tfstate`, `inventory`, and `ansible-vars.yaml` land in `/workspace`.

### Passthrough tools
```bash
./oss-k8s.sh tf plan -var-file=terraform.tfvars   # raw Terraform
./oss-k8s.sh k get nodes                           # kubectl
./oss-k8s.sh helm list                             # Helm
```

### Before every commit
```bash
terraform fmt -recursive
git commit -s   # DCO sign-off required
```

### Terraform tests
```bash
export TF_VAR_vsphere_user=... TF_VAR_vsphere_password=... TF_VAR_vsphere_server=...
terraform test --verbose --filter=tests/variable_defaults.tftest.hcl
```

## OpenStack / HPOS-Specific Nuances
- `~/.openstack_creds.env` is auto-sourced by both `oss-k8s.sh` and `allocate-vip.sh`; `OS_*` vars map to `TF_VAR_openstack_*`. Set `OS_INSECURE=true` and `OS_PROJECT_DOMAIN_NAME` for HPOS environments.
- Placeholder vSphere vars are injected automatically (`TF_VAR_vsphere_user=openstack-unused`) because the vSphere provider still appears in the dependency graph.
- **Before `apply`**: run `./allocate-vip.sh` to reserve two floating IPs — `cluster_vip_ip` (kube-vip HA VIP) and `cluster_lb_addresses` (LoadBalancer VIP) — which are written back into `terraform.tfvars`. Both IPs **must be registered in DNS** before running `setup`/`install`.
- After `terraform apply`, `patch_vip_allowed_pairs()` PUTs `allowed_address_pairs` (VIP + LB IPs) on all control-plane Neutron ports via the Keystone/Neutron API — OpenStack blocks this at port-creation time.
- `cluster_vip_fqdn` must be set explicitly in `terraform.tfvars` (e.g., `<prefix>-vip.unx.sas.com`) after DNS registration.
- Full step-by-step HPOS guide: `docs/user/OpenStackHPOSUsage.md`.

## OS / cgroup v2 Requirement
Kubernetes ≥ 1.35 requires **cgroup v2**. Supported `vm_os` values (set in `ansible-vars.yaml`):
- `ubuntu` → Ubuntu 22.04 (Jammy) or 24.04 (Noble)
- `rocky` → Rocky Linux 9 / RHEL 9

Ubuntu 20.04 and Rocky/RHEL 8 (cgroup v1) are **not supported**.

`cluster_cri_version` must be **≥ 2.0.0** (containerd) for `KubeletCgroupDriverFromCRI` auto-detection (GA K8s 1.34; required for K8s 1.36+ which drops explicit `cgroupDriver`). Default: `2.2.2`.

## Node Pool Pattern
Defined in `terraform.tfvars` under `node_pools`. Reserved keys `control_plane` and `system` are split out in `locals.tf`; all other keys become worker pools. Per-pool `flavor` (OpenStack) or `cpus`/`memory` (vSphere) extend `node_pool_defaults`. `control_plane` must have an odd count (≥ 3 for HA). `system` nodes require label `"kubernetes.azure.com/mode" = "system"`.

## Cluster Naming Convention
`local.cluster_name = "${var.prefix}-oss"` — used for all resource names, kubeconfig files (`<prefix>-oss-kubeconfig.conf`), Ansible inventory group prefixes, and Neutron port naming (`<prefix>-oss-control-plane-*`).

## Terraform Coding Standards
- `variables.tf` / `outputs.tf` / `locals.tf` at every module level (see `CodingStandards.txt`).
- Locals hide conditional/computed logic to keep `main.tf` readable.
- New modules: `modules/<name>/main.tf` + `variables.tf` + `outputs.tf`.
- `tflint-ignore:` directives in `variables.tf` suppress warnings for provider-unused cross-platform variables.

## CI / Linting
Hadolint, ShellCheck, and TFLint run on every branch push (`.github/workflows/linter-analysis.yaml`). Configs in `linting-configs/`.

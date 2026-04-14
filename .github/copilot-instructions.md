# GitHub Copilot Instructions — viya4-iac-k8s

## Project Purpose
Automates provisioning of open-source Kubernetes clusters for SAS Viya 4 deployments on **bare metal**, **VMware vSphere/vCenter**, or **OpenStack**. Two-stage pipeline: Terraform provisions VMs (vSphere/OpenStack only), then Ansible configures the OS and installs Kubernetes via kubeadm.

## Architecture Overview
- **`oss-k8s.sh`** — single entry point; orchestrates Terraform + Ansible. Rewrites `provider.tf` and surgically strips `main.tf` at runtime before every Terraform invocation.
- **Terraform** (`*.tf` at root + `modules/`) — provisions infrastructure. For bare metal, only generates `inventory` and `ansible-vars.yaml`; no VMs created.
- **Ansible** (`playbooks/`, `roles/`) — called by `oss-k8s.sh` with generated `inventory` and `ansible-vars.yaml` (both rendered from `templates/ansible/` via `local_file` Terraform resources).
- **Data flow**: `terraform apply` → renders `inventory` + `ansible-vars.yaml` → `ansible-playbook` consumes them.

## `SYSTEM` / `deployment_type` Is the Master Switch
Every conditional in `main.tf`, `locals.tf`, and `oss-k8s.sh` keys off this value.
- Set via env var: `export SYSTEM=openstack` (or `vsphere` / `bare_metal`). Default: `bare_metal`.
- Passed to Terraform as `-var "deployment_type=$SYSTEM"`.
- **Never set `deployment_type` in `terraform.tfvars`** — use `SYSTEM=` so `oss-k8s.sh` also rewrites `provider.tf` and `main.tf` correctly.

## Runtime File Mutation (Critical)
`oss-k8s.sh` mutates tracked files before every Terraform run — do not hand-edit them:
- **`provider.tf`** — replaced wholesale with the provider block for the active `SYSTEM`. Committed baseline is the OpenStack form (used for CI linting).
- **`main.tf`** — `awk` strips the opposite platform's module blocks; backup kept at `.main.tf.iac-backup`, restored on `EXIT` trap. A `runtime-provider-stubs.tf` is also generated to satisfy vSphere module references during OpenStack runs (using `modules/noop/` as a no-op stub).

## Key Developer Workflows

### Full lifecycle (native)
```bash
export SYSTEM=openstack   # or vsphere / bare_metal
# OpenStack: source ~/.openstack_creds.env  (OS_* vars auto-mapped to TF_VAR_openstack_*)
./oss-k8s.sh apply setup install        # provision → OS setup → K8s install
./oss-k8s.sh uninstall cleanup destroy  # tear down
```

### Docker
```bash
docker run --rm -v $(pwd):/workspace \
  -e IAC_TOOLING=docker -e SYSTEM=openstack \
  viya4-iac-k8s:latest apply setup install
```

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

## OpenStack-Specific Nuances
- `~/.openstack_creds.env` is auto-sourced; `OS_*` vars map to `TF_VAR_openstack_*`.
- Placeholder vSphere vars are injected automatically (`TF_VAR_vsphere_user=openstack-unused`) because the vSphere provider still appears in the dependency graph.
- After `terraform apply`, `patch_vip_allowed_pairs()` PUTs `allowed_address_pairs` on control-plane Neutron ports via the API directly — OpenStack blocks this at port-creation time.
- `allocate_vip_floating_ip()` in `oss-k8s.sh` (or `allocate-vip.sh`) allocates two floating IPs (`cluster_vip_ip` for kube-vip HA, `cluster_lb_addresses` for LoadBalancer services) and writes them back into `terraform.tfvars`. Both must be registered in DNS before running `setup`/`install`.
- `cluster_vip_fqdn` defaults to `${prefix}-oss-vip.${cluster_domain}` if not set explicitly.

## OS / cgroup v2 Requirement
Kubernetes ≥ 1.35 requires **cgroup v2**. Only supported guest OSes:
- `ubuntu` → Ubuntu 22.04 (Jammy) or 24.04 (Noble)
- `rocky` → Rocky Linux 9 / RHEL 9

Ubuntu 20.04 and Rocky/RHEL 8 (cgroup v1) are **not supported**. `vm_os` is set in `ansible-vars.yaml` / the template.

`cluster_cri_version` must be **≥ 2.0.0** (containerd) for `KubeletCgroupDriverFromCRI` auto-detection (GA in K8s 1.34; required for K8s 1.36+ which drops the explicit `cgroupDriver` setting). Default: `2.2.2`.

## Node Pool Pattern
Defined in `terraform.tfvars` under `node_pools`. Reserved keys `control_plane` and `system` are split out in `locals.tf`; all other keys become worker node pools. Per-pool `flavor` (OpenStack) or CPU/memory overrides (vSphere) extend `node_pool_defaults`.

## Cluster Naming Convention
`local.cluster_name = "${var.prefix}-oss"` — used for all resource names, kubeconfig files (`<prefix>-oss-kubeconfig.conf`), and Ansible inventory group prefixes.

## Terraform Coding Standards
- `variables.tf` / `outputs.tf` / `locals.tf` at every module level (see `CodingStandards.txt`).
- Locals hide conditional/computed logic to keep `main.tf` readable.
- New modules: `modules/<name>/main.tf` + `variables.tf` + `outputs.tf`.
- `tflint-ignore:` directives in `variables.tf` suppress warnings for provider-unused cross-platform variables.

## CI / Linting
Hadolint, ShellCheck, and TFLint run on every branch push (`.github/workflows/linter-analysis.yaml`). Configs in `linting-configs/`.

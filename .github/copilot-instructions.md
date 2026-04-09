# GitHub Copilot Instructions — viya4-iac-k8s

## Project Purpose
Automates provisioning of open-source Kubernetes clusters for SAS Viya 4 deployments on **bare metal**, **VMware vSphere/vCenter**, or **OpenStack**. The pipeline has two stages: Terraform provisions VMs (vSphere/OpenStack only), then Ansible configures the OS and installs Kubernetes.

## Architecture Overview
- **Terraform** (`*.tf` at root + `modules/`) — provisions infrastructure for vSphere or OpenStack. For bare metal, Terraform only generates config files; no VMs are created.
- **Ansible** (`playbooks/`, `roles/`, `ansible.cfg`) — configures machines and installs Kubernetes using kubeadm.
- **`oss-k8s.sh`** — the single entry point that orchestrates both Terraform and Ansible. It rewrites `provider.tf` and patches `main.tf` at runtime based on `SYSTEM=vsphere|openstack|bare_metal`.
- **Terraform outputs** feed directly into Ansible via two generated files: `inventory` and `ansible-vars.yaml` (rendered from `templates/ansible/`).

## `deployment_type` / `SYSTEM` Is the Master Switch
Every conditional in `main.tf`, `locals.tf`, and `oss-k8s.sh` keys off this value.  
- `SYSTEM` env var → passed as `-var "deployment_type=$SYSTEM"` to Terraform.  
- Valid values: `bare_metal` (default), `vsphere`, `openstack`.  
- **Never set `deployment_type` directly in `terraform.tfvars`** for OpenStack/vSphere; use `SYSTEM=` instead so `oss-k8s.sh` also rewrites `provider.tf` and `main.tf` correctly.

## Runtime File Mutation (Critical)
`oss-k8s.sh` dynamically rewrites two tracked files before every Terraform run:
- **`provider.tf`** — replaced wholesale to include only the required provider (`vsphere` or `openstack`).
- **`main.tf`** — vSphere-only or OpenStack-only module blocks are stripped via `awk`; a backup is kept at `.main.tf.iac-backup` and restored on `EXIT`.
- **`modules/noop/`** exists solely as a stub so OpenStack runs satisfy vSphere module references without creating resources.

**Do not hand-edit `provider.tf`** — it is overwritten at runtime. The committed `provider.tf` baseline is the OpenStack form used for CI linting.

## Key Developer Workflows

### Running the full lifecycle (native)
```bash
export SYSTEM=openstack   # or vsphere / bare_metal
export $(grep -v '^#' ~/.openstack_creds.env | xargs)
./oss-k8s.sh apply setup install   # provision + OS setup + K8s install
./oss-k8s.sh uninstall cleanup destroy  # tear down
```

### Running via Docker
```bash
docker run --rm -v $(pwd):/workspace \
  -e IAC_TOOLING=docker -e SYSTEM=openstack \
  viya4-iac-k8s:latest apply setup install
```

### Terraform only (debugging)
```bash
export SYSTEM=vsphere
./oss-k8s.sh tf plan -var-file=terraform.tfvars
```

### Formatting (required before committing)
```bash
terraform fmt -recursive
```

### Running Terraform tests
```bash
export TF_VAR_vsphere_user=... TF_VAR_vsphere_password=... TF_VAR_vsphere_server=...
terraform test --verbose --filter=tests/variable_defaults.tftest.hcl
```

## Terraform Coding Standards (`CodingStandards.txt`)
- Variables → `variables.tf`, outputs → `outputs.tf`, locals → `locals.tf` at each module level.
- Locals are used to hide conditional/computed logic, keeping `main.tf` readable.
- New modules go under `modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`.
- Sign commits: `git commit -s` (DCO check in CI).
- Run `terraform fmt -recursive` before every commit.

## Node Pool Pattern
Node pools are defined in `terraform.tfvars` under `node_pools`. Reserved keys `control_plane` and `system` are separated in `locals.tf`; all others are worker nodes. Per-pool `flavor` (OpenStack) or CPU/memory overrides (vSphere) extend `node_pool_defaults`.

## OpenStack-Specific Nuances
- Credentials auto-sourced from `~/.openstack_creds.env`; env vars `OS_*` are mapped to `TF_VAR_openstack_*`.
- Placeholder vSphere vars (`TF_VAR_vsphere_user=openstack-unused`) must be set because the vSphere provider is still referenced in the graph — `oss-k8s.sh` does this automatically.
- After `terraform apply`, `patch_vip_allowed_pairs()` in `oss-k8s.sh` calls the Neutron API directly to add the kube-vip VIP to `allowed_address_pairs` on control-plane ports (most OpenStack environments block this at creation time).
- `cluster_vip_ip` must be a free IP on the tenant network; `cluster_vip_fqdn` must resolve on all nodes.

## Cluster Name Convention
`local.cluster_name = "${var.prefix}-oss"` — all generated resource names, kubeconfig files, and Ansible inventory groups use this pattern.

## CI / Linting
Linting workflow (`.github/workflows/linter-analysis.yaml`) runs Hadolint, ShellCheck, and TFLint on every branch push. Configs live in `linting-configs/`. TFLint uses `tflint-ignore:` directives in `variables.tf` for provider-unused variables.

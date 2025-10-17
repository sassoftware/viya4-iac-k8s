# SAS Viya 4 IaC for Kubernetes - AI Agent Instructions

## Project Overview
This is a hybrid Terraform + Ansible Infrastructure as Code (IaC) project that automates Kubernetes cluster provisioning for SAS Viya 4 deployments. It supports two deployment modes: **VMware vSphere** (using Terraform to create VMs) and **bare-metal** (using existing machines with Ansible only).

## Architecture & Key Components

### Dual Deployment Architecture
- **vSphere mode**: Terraform provisions VMs → Ansible configures Kubernetes
- **bare-metal mode**: Ansible-only configuration on existing machines
- The `deployment_type` variable controls which path is taken
- Both modes converge on the same Ansible playbooks for Kubernetes setup

### Node Types & Roles
- **Control Plane**: 3+ nodes for HA, managed by `roles/kubernetes/control_plane/`
- **System nodes**: Infrastructure services (jump server, NFS, PostgreSQL)
- **Worker nodes**: Application workloads, defined in `node_pools` variable
- **VIP management**: kube-vip provides cluster virtual IP and load balancing

### Key Configuration Files
- `terraform.tfvars`: vSphere infrastructure settings (examples in `examples/vsphere/`)
- `ansible-vars.yaml`: Kubernetes cluster configuration (examples in `examples/bare-metal/`)
- `inventory`: Target machine definitions for bare-metal deployments

## Essential Workflows

### Development & Testing
```bash
# Build and run in Docker (recommended)
docker build -t viya4-iac-k8s .
docker run --env-file ~/.vsphere_creds.env --volume=$(pwd):/workspace viya4-iac-k8s apply

# Native execution
./oss-k8s.sh apply    # Create cluster
./oss-k8s.sh update   # Update existing cluster
./oss-k8s.sh destroy  # Tear down cluster
```

### Module Structure Patterns
- Terraform modules in `modules/`: reusable VM (`vm/`) and server (`server/`) components
- Ansible roles in `roles/`: organized by technology stack (`kubernetes/`, `systems/`)
- Role dependencies: common → CRI → control plane → CNI → load balancer

## Project-Specific Conventions

### Variable Naming & Organization
- Terraform variables use `snake_case` with clear prefixes (`vsphere_`, `cluster_`, `node_`)
- Ansible variables follow same pattern but with dots in YAML (`kubernetes.version`)
- Complex objects like `node_pools` use nested maps with defaults in `locals.tf`

### Template & Generation Patterns
- Ansible inventory is auto-generated from Terraform outputs for vSphere mode
- Template files in `templates/ansible/` provide base configurations
- The `prefix` variable namespaces all resource names consistently

### Networking & Load Balancing
- **kube-vip**: Default LB, provides both VIP and cloud provider functionality
- **MetalLB**: Alternative LB, required for SingleStore compatibility
- Load balancer addresses configured as CIDR ranges or IP pools in `cluster_lb_addresses`

### Version Management
- Kubernetes versions: 1.29-1.31 supported (1.32 TBD)
- CNI: Calico only, version pinned in ansible-vars
- CRI: containerd only, version pinned
- Upgrade control via `kubernetes_upgrade_allowed` flag

## Critical Integration Points

### Docker Containerization
- `Dockerfile` creates portable execution environment with all tools
- Entrypoint is `oss-k8s.sh`, supports same commands as native execution
- Volume mounts required: `--volume=$(pwd):/workspace` for persistence
- Environment files pattern for secure credential passing

### Ansible Role Dependencies
```yaml
# Execution order in kubernetes-install.yaml
kubernetes/common → kubernetes/cri/containerd → kubernetes/toolbox
→ kubernetes/vip/primary → kubernetes/control_plane/init/primary
→ kubernetes/cni/calico → kubernetes/control_plane/init/secondary
```

### State Management
- Terraform state in `terraform.tfstate` (local backend)
- Kubeconfig output to workspace root for kubectl access
- No remote state - designed for single-operator use

## Common Troubleshooting Patterns

### Credential Management
- vSphere: `TF_VAR_vsphere_user` and `TF_VAR_vsphere_password` environment variables
- Ansible: `ansible_user` with passwordless sudo required
- SSH keys: `system_ssh_keys_dir` points to public keys for machine access

### Network Configuration Issues
- Static IP allocation via `ip_addresses` array in node pools
- DHCP fallback when IP arrays empty
- Gateway/netmask must allow access from execution environment

### Resource Sizing Defaults
- Control plane: 2 CPU, 4GB RAM minimum
- Nodes: customizable via `node_pool_defaults` and per-pool overrides
- Disk sizing: OS disk + optional `misc_disks` for data volumes

When modifying this codebase, always consider both deployment modes and test changes in the Docker environment to ensure tool version consistency.
# Kubernetes kubeadm Role

## Overview

This role automates the deployment of a Kubernetes cluster using `kubeadm` modules. It handles all stages of cluster initialization from preflight checks to Azure cloud provider (CCM) configuration with automatic load balancer integration.

## Features

- **Modular Design**: Six separate task files for different deployment stages
- **Multi-node Support**: Handles primary control plane, secondary control planes, and worker nodes
- **Container Runtime Flexibility**: Supports Docker, containerd, and CRI-O
- **Azure CCM Integration**: Automatic deployment of Azure Cloud Controller Manager
- **Load Balancer Support**: Configures Azure Standard Load Balancer for Kubernetes services
- **Idempotent Execution**: All tasks are safe to re-run
- **Comprehensive Error Handling**: Proper validation and wait conditions

## Role Structure

```
roles/kubernetes/kubeadm/
├── tasks/
│   ├── main.yaml                      # Main task dispatcher
│   ├── 01-preflight-checks.yaml       # System validation
│   ├── 02-install-runtime.yaml        # Container runtime installation
│   ├── 03-install-kubeadm.yaml        # kubeadm/kubectl/kubelet installation
│   ├── 04-init-cluster.yaml           # Primary control plane initialization
│   ├── 05-join-cluster.yaml           # Node joining (workers & secondary CPs)
│   └── 06-configure-azure-cloud.yaml  # Azure CCM & load balancer setup
├── handlers/
│   └── main.yaml                      # Service restart handlers
├── defaults/
│   └── main.yaml                      # Default variables (highly customizable)
├── vars/
│   └── main.yaml                      # Fixed/derived variables
├── templates/
│   ├── kubeadm-config.yaml.j2         # kubeadm init configuration
│   ├── kubeadm-join-config.yaml.j2    # kubeadm join configuration
│   └── azure-ccm-config.yaml.j2       # Azure cloud provider configuration
└── README.md                           # This file
```

## Task Files

### 01-preflight-checks.yaml
Validates system requirements:
- Kernel version check
- CPU and memory verification
- Swap disable and fstab cleanup
- Kernel module loading (overlay, br_netfilter)
- sysctl configuration for networking
- System package installation

### 02-install-runtime.yaml
Installs container runtime based on `kubernetes_cri` variable:
- **Docker**: APT/Yum installation, daemon configuration
- **containerd**: Installation and config generation
- **CRI-O**: Installation with repository setup

### 03-install-kubeadm.yaml
Installs Kubernetes tools:
- Adds Google Cloud Kubernetes repository
- Installs kubeadm, kubectl, kubelet
- Holds packages at current version (prevents auto-upgrades)
- Enables kubelet service

### 04-init-cluster.yaml
Initializes Kubernetes cluster (primary control plane only):
- Checks if cluster already initialized
- Generates kubeadm configuration from template
- Runs `kubeadm init` with Azure cloud provider
- Extracts bootstrap token and CA certificate hash
- Generates join configuration for other nodes
- Fetches join config to localhost for distribution
- Waits for API server readiness

### 05-join-cluster.yaml
Joins nodes to cluster (workers and secondary control planes):
- Waits for control plane API server
- Fetches join configuration from primary CP
- Runs `kubeadm join`
- Verifies node status in cluster
- Supports serial execution for controlled node joining

### 06-configure-azure-cloud.yaml
Configures Azure Cloud Provider (primary control plane only):
- Generates Azure CCM configuration
- Creates secret with Azure credentials
- Creates ServiceAccount for cloud-controller-manager
- Deploys ClusterRole and ClusterRoleBinding for RBAC
- Deploys Azure CCM as DaemonSet
- Waits for CCM pods readiness
- Creates ConfigMap for load balancer settings
- Uses `kubernetes.core.k8s` modules (no kubectl commands)

## Variables

### Default Variables (defaults/main.yaml)

Key variables you can override:

```yaml
# Kubernetes version
kubernetes_version: "1.28.0"

# Container runtime (docker, containerd, crio)
kubernetes_cri: "containerd"

# CNI plugin
kubernetes_cni: "calico"

# Cluster networking
kubeadm_pod_network_cidr: "10.42.0.0/16"
kubeadm_service_cidr: "10.43.0.0/16"

# Azure settings
azure_location: "eastus"
azure_resource_group: "my-resource-group"
azure_client_id: "***"
azure_client_secret: "***"
azure_tenant_id: "***"
azure_subscription_id: "***"

# Load balancer
azure_lb_type: "Standard"

# Enable/disable cloud provider
enable_cloud_provider: true
deployment_type: "azure"
```

### Derived Variables (vars/main.yaml)

Fixed variables computed from defaults:
- `cri_socket`: Container runtime socket path
- `kubeadm_dns_ip`: DNS server IP (10.43.0.10)
- `kubelet_data_dir`: Kubelet data directory (/var/lib/kubelet)

## Usage

### Typical Playbook Structure

```yaml
# Stage 1: Preflight checks (all nodes)
- hosts: all
  name: Kubernetes Setup - Preflight Checks
  become: true
  roles:
    - { role: kubernetes/common }

# Stage 2: Initialize cluster (primary control plane)
- hosts: k8s_control_plane[0]
  name: Kubernetes Cluster - Initialize
  become: true
  roles:
    - { role: kubernetes/kubeadm }

# Stage 3: Join workers
- hosts: k8s_node
  name: Kubernetes Cluster - Join Workers
  become: true
  serial: 1
  roles:
    - { role: kubernetes/kubeadm }

# Stage 4: Join secondary control planes
- hosts: k8s_control_plane[1:]
  name: Kubernetes Cluster - Join Secondary CPs
  become: true
  roles:
    - { role: kubernetes/kubeadm }

# Stage 5: Install CNI
- hosts: k8s_control_plane[0]
  name: Kubernetes Cluster - Install CNI
  become: true
  roles:
    - { role: "kubernetes/cni/{{ kubernetes_cni }}" }

# Stage 6: Configure cloud provider
- hosts: k8s_control_plane[0]
  name: Kubernetes Cloud Provider - Configure Azure
  become: true
  roles:
    - { role: kubernetes/cloud-provider }
```

### Inventory Requirements

Organize your inventory with these host groups:

```yaml
[k8s_control_plane]
cp1  ansible_host=10.0.0.10
cp2  ansible_host=10.0.0.11
cp3  ansible_host=10.0.0.12

[k8s_node]
worker1  ansible_host=10.0.0.20
worker2  ansible_host=10.0.0.21

[k8s:children]
k8s_control_plane
k8s_node
```

### Running the Role

```bash
# From repository root
ansible-playbook playbooks/kubernetes-install.yaml \
  -i inventory/hosts.yaml \
  -e "@topologies/azure/ansible-vars.yaml"

# Or with specific tags
ansible-playbook playbooks/kubernetes-install.yaml \
  -i inventory/hosts.yaml \
  -t "cluster-init,cluster-join"
```

## Azure Cloud Provider Configuration

### What Gets Deployed

When task 06 runs, the following Azure resources are created in Kubernetes:

1. **Secret** (`azure-cloud-provider`): Stores Azure credentials and cloud config
2. **ServiceAccount** (`cloud-controller-manager`): For CCM pod authentication
3. **ClusterRole**: RBAC permissions for node/service/endpoint management
4. **ClusterRoleBinding**: Binds role to ServiceAccount
5. **DaemonSet** (`cloud-controller-manager`): Runs CCM on all control planes
6. **ConfigMap** (`azure-load-balancer-config`): Load balancer settings

### Load Balancer Integration

Once Azure CCM is deployed:
- `LoadBalancer` services automatically get Azure Load Balancer IPs
- Internal/External load balancer types supported
- Health probes configured automatically
- No manual Azure load balancer creation needed

### Azure Service Principal Requirements

The Azure service principal (client ID/secret) needs these permissions:
- Compute: Read VMs/VMSS
- Network: Read/write load balancers, public IPs
- Storage: Read storage accounts (for boot diagnostics)

## Troubleshooting

### CCM Pods Not Ready

```bash
# Check CCM pod logs
kubectl logs -n kube-system -l component=cloud-controller-manager

# Verify Azure credentials secret
kubectl get secret -n kube-system azure-cloud-provider

# Check DaemonSet status
kubectl get daemonset -n kube-system cloud-controller-manager
```

### Node Not Joining Cluster

```bash
# Check kubelet logs
journalctl -u kubelet -f

# Verify kubeadm join configuration
cat /tmp/kubeadm-join-config.yaml

# Check network connectivity to control plane
nc -zv <control-plane-ip> 6443
```

### API Server Not Starting

```bash
# Check API server logs
journalctl -u kubelet -f

# Verify kubeadm init configuration
cat /tmp/kubeadm-config.yaml

# Check system resources
free -h
df -h
```

### Load Balancer Not Getting Assigned

```bash
# Check if CCM pods are running
kubectl get pods -n kube-system -l component=cloud-controller-manager

# Check CCM logs for errors
kubectl logs -n kube-system -l component=cloud-controller-manager

# Verify Azure permissions
# Service principal must have Network Contributor role
```

## Tags

Use Ansible tags to run specific stages:

```yaml
tags:
  - kubeadm           # All kubeadm role tasks
  - preflight         # Preflight checks
  - runtime           # Container runtime installation
  - kubeadm-tools     # kubeadm/kubectl/kubelet tools
  - cluster-init      # Cluster initialization
  - cluster-join      # Node joining
  - azure-ccm         # Azure cloud provider
  - cloud-provider    # Cloud provider (alias for azure-ccm)
```

## Security Considerations

1. **Secrets Management**: Azure credentials stored in Kubernetes secrets
2. **RBAC**: CCM runs with limited ClusterRole permissions
3. **Network Policies**: Consider implementing network policies post-deployment
4. **Certificate Rotation**: kubeadm handles certificate generation and rotation
5. **Service Account Tokens**: Default 8760h expiry (configurable)

## Extensibility

To add support for other cloud providers (AWS, GCP):

1. Copy `roles/kubernetes/cloud-provider/tasks/azure.yaml`
2. Create `roles/kubernetes/cloud-provider/tasks/aws.yaml` or `gcp.yaml`
3. Implement provider-specific CCM deployment
4. Update playbook to call `kubernetes/cloud-provider` role with `deployment_type`

See `roles/kubernetes/cloud-provider/README.md` for details.

## Performance Notes

- **Serial Execution**: Node joining uses `serial: 1` to prevent cluster overload
- **Wait Conditions**: All wait tasks have 300s timeout
- **Resource Requests**: CCM requests 100m CPU, 100Mi memory (adjustable)
- **Load Balancer**: Standard SKU recommended for production (Premium available)

## References

- [kubeadm Documentation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Azure Cloud Provider](https://github.com/kubernetes-sigs/cloud-provider-azure)
- [Kubernetes on Azure](https://azure.microsoft.com/en-us/services/kubernetes-service/)
- [Medium: Kubernetes on Azure VMs with kubeadm](https://saraswathilakshman.medium.com/setting-up-a-kubernetes-cluster-using-azure-vms-and-kubeadm-bc306ea6be90)

## Support

For issues or questions:
1. Check logs: `journalctl -u kubelet -f`
2. Verify connectivity: `nc -zv <control-plane> 6443`
3. Review Azure credentials in `azure-cloud-provider` secret
4. Enable Ansible debug: `ansible-playbook -vvv playbooks/kubernetes-install.yaml`

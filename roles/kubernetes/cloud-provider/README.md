# Kubernetes Cloud Provider Role

## Overview

This role abstracts cloud provider configuration for Kubernetes clusters. It uses a **dispatcher pattern** to support multiple cloud providers (Azure fully implemented, AWS and GCP templates ready for future implementation).

## Architecture

### Dispatcher Pattern

The role routes to provider-specific implementations based on the `deployment_type` variable:

```
cloud-provider (main.yaml)
├── deployment_type == "azure"  → azure.yaml (FULLY IMPLEMENTED)
├── deployment_type == "aws"    → aws.yaml (TEMPLATE FOR FUTURE)
└── deployment_type == "gcp"    → gcp.yaml (TEMPLATE FOR FUTURE)
```

## Role Structure

```
roles/kubernetes/cloud-provider/
├── tasks/
│   ├── main.yaml              # Dispatcher (routes by deployment_type)
│   ├── azure.yaml             # Azure implementation (COMPLETE)
│   ├── aws.yaml               # AWS template (READY FOR FUTURE)
│   └── gcp.yaml               # GCP template (READY FOR FUTURE)
├── defaults/
│   └── main.yaml              # deployment_type, enable_cloud_provider flags
├── vars/
│   ├── azure.yaml             # Azure-specific variables (credentials, LB config)
│   ├── aws.yaml               # AWS template variables
│   └── gcp.yaml               # GCP template variables
├── templates/
│   ├── azure-ccm-config.yaml.j2   # Azure CCM JSON config
│   ├── aws-ccm-config.yaml.j2     # AWS config template
│   └── gcp-ccm-config.yaml.j2     # GCP config template
└── README.md                  # This file
```

## Features

### Current Implementation (Azure)

- ✅ **Complete Azure Cloud Controller Manager (CCM) deployment**
- ✅ **Azure Load Balancer integration (Standard SKU)**
- ✅ **Service account and RBAC configuration**
- ✅ **Credentials secret management**
- ✅ **DaemonSet deployment with pod readiness checks**
- ✅ **ConfigMap for load balancer settings**

### Future Implementation Ready (AWS/GCP)

- 📋 **Dispatcher pattern infrastructure in place**
- 📋 **Variable templates defined**
- 📋 **Configuration file placeholders created**
- 📋 **Implementation guide documented**

## Variables

### Default Variables (defaults/main.yaml)

```yaml
# Cloud provider selection
deployment_type: "azure"

# Enable/disable cloud provider deployment
enable_cloud_provider: true

# Wait settings
cloud_provider_wait_timeout: 300
cloud_provider_wait_delay: 5
```

### Provider-Specific Variables

Sourced from `vars/{provider}.yaml`:

#### Azure (vars/azure.yaml)
```yaml
azure_client_id: "***"
azure_client_secret: "***"
azure_tenant_id: "***"
azure_subscription_id: "***"
azure_resource_group: "my-resource-group"
azure_location: "eastus"
azure_ccm_version: "1.28.0"
azure_lb_type: "Standard"
azure_vnet_name: "prefix-vnet"
azure_subnet_name: "prefix-subnet-k8s"
azure_nsg_name: "prefix-sg"
```

#### AWS (vars/aws.yaml) - Template
```yaml
aws_access_key_id: "***"
aws_secret_access_key: "***"
aws_region: "us-east-1"
aws_vpc_id: "vpc-xxxxx"
aws_security_group_id: "sg-xxxxx"
```

#### GCP (vars/gcp.yaml) - Template
```yaml
gcp_project_id: "my-project"
gcp_zone: "us-central1-a"
gcp_service_account: "***"
gcp_service_account_json: "***"
```

## Usage

### Basic Playbook

```yaml
# Configure cloud provider after cluster initialization
- hosts: k8s_control_plane[0]
  name: Kubernetes Cloud Provider - Configure
  become: true
  roles:
    - { role: kubernetes/cloud-provider }
  vars:
    deployment_type: "azure"
    enable_cloud_provider: true
```

### With Custom Variables

```yaml
- hosts: k8s_control_plane[0]
  name: Kubernetes Cloud Provider - Azure
  become: true
  roles:
    - { role: kubernetes/cloud-provider }
  vars:
    deployment_type: "azure"
    azure_location: "westeurope"
    azure_lb_type: "Standard"
```

### Full Kubernetes Installation Playbook

```yaml
---
# Multi-stage Kubernetes deployment with cloud provider

# Stage 1: Preflight checks (all nodes)
- hosts: all
  name: Preflight Checks
  become: true
  roles:
    - { role: kubernetes/common }

# Stage 2: Initialize cluster (primary control plane)
- hosts: k8s_control_plane[0]
  name: Initialize Kubernetes Cluster
  become: true
  roles:
    - { role: kubernetes/kubeadm }

# Stage 3: Join worker nodes
- hosts: k8s_node
  name: Join Worker Nodes
  become: true
  serial: 1
  roles:
    - { role: kubernetes/kubeadm }

# Stage 4: Join secondary control planes
- hosts: k8s_control_plane[1:]
  name: Join Secondary Control Planes
  become: true
  roles:
    - { role: kubernetes/kubeadm }

# Stage 5: Install CNI
- hosts: k8s_control_plane[0]
  name: Install Container Network Interface
  become: true
  roles:
    - { role: "kubernetes/cni/{{ kubernetes_cni }}" }

# Stage 6: Configure cloud provider ← This role
- hosts: k8s_control_plane[0]
  name: Configure Cloud Provider
  become: true
  roles:
    - { role: kubernetes/cloud-provider }
  vars:
    deployment_type: "{{ deployment_type }}"
```

## Supported Cloud Providers

### Azure (IMPLEMENTED ✅)

**Status**: Fully functional and tested

**Components Deployed**:
1. Azure credentials Secret
2. ServiceAccount for cloud-controller-manager
3. ClusterRole with required permissions
4. ClusterRoleBinding for RBAC
5. DaemonSet running Azure CCM pods
6. ConfigMap for load balancer settings

**Load Balancer Integration**:
- Automatic provisioning of Azure Load Balancer for `LoadBalancer` services
- Standard SKU (Premium available via variables)
- Health probe configuration
- Internal and external load balancer support

**Requirements**:
- Azure service principal with appropriate permissions
- Network Contributor role on resource group
- Azure VNet and subnets properly configured

### AWS (TEMPLATE 📋)

**Status**: Ready for implementation

**To Implement**:
1. Create AWS CCM DaemonSet deployment
2. Configure IAM roles and service account
3. Deploy AWS Load Balancer Controller
4. Handle ELB/NLB service type routing
5. Configure storage class for EBS volumes

**Expected Features**:
- Network Load Balancer (NLB) and Classic Load Balancer support
- Cross-zone load balancing
- Security group configuration
- EC2 instance metadata integration

### GCP (TEMPLATE 📋)

**Status**: Ready for implementation

**To Implement**:
1. Create GCP CCM DaemonSet deployment
2. Configure service account credentials
3. Deploy GCP Load Balancer Controller
4. Handle Cloud Load Balancing integration
5. Configure storage class for Persistent Disks

**Expected Features**:
- Google Cloud Load Balancing integration
- Workload Identity (IRSA equivalent)
- GCP Persistent Disk provisioning
- Instance group management

## Implementation Guide - Adding New Cloud Providers

### Step 1: Create Provider Task File

Create `roles/kubernetes/cloud-provider/tasks/{provider}.yaml`:

```yaml
---
# {Provider} cloud provider implementation

- name: "{Provider} cloud provider configuration"
  debug:
    msg: "Configuring {Provider} Cloud Provider"
  tags:
    - cloud-provider
    - {provider}

- name: "Deploy {Provider} CCM"
  # Your implementation here
  tags:
    - cloud-provider
    - {provider}
```

### Step 2: Create Provider Variables File

Create `roles/kubernetes/cloud-provider/vars/{provider}.yaml`:

```yaml
---
# {Provider} cloud provider variables

{provider}_client_id: "{{ {provider}_client_id | default('') }}"
{provider}_region: "{{ {provider}_region | default('us-east-1') }}"
# Add more variables as needed
```

### Step 3: Create Configuration Template

Create `roles/kubernetes/cloud-provider/templates/{provider}-ccm-config.yaml.j2`:

```jinja2
# {Provider} cloud provider configuration
# Configuration for CCM deployment
```

### Step 4: Update Dispatcher (main.yaml)

The dispatcher automatically includes any `{provider}.yaml` file when `deployment_type == "{provider}"`.

### Step 5: Testing

```bash
# Test provider detection
ansible-playbook playbooks/kubernetes-install.yaml \
  -i inventory/hosts \
  -e "deployment_type={provider}" \
  -t cloud-provider -vv
```

## Tags

```yaml
tags:
  - cloud-provider        # All cloud provider tasks
  - azure                 # Azure provider only
  - aws                   # AWS provider only (when implemented)
  - gcp                   # GCP provider only (when implemented)
```

## Conditional Execution

### Skip Cloud Provider

```bash
# Skip cloud provider configuration
ansible-playbook playbooks/kubernetes-install.yaml \
  -e "enable_cloud_provider=false"
```

### Change Deployment Type

```bash
# Deploy for AWS (when implemented)
ansible-playbook playbooks/kubernetes-install.yaml \
  -e "deployment_type=aws"
```

## Troubleshooting

### Cloud Provider Not Deploying

Check if `enable_cloud_provider` is true and `deployment_type` matches:

```bash
# Verify variables
ansible-playbook playbooks/kubernetes-install.yaml \
  -e "enable_cloud_provider=true" \
  -e "deployment_type=azure" \
  -t cloud-provider -vvv
```

### Unsupported Cloud Provider

If you get "Task not found" error, the provider isn't implemented yet. See "Implementation Guide" above.

### Variable Loading Issues

Ensure provider-specific variables are loaded:

```bash
# Debug variable loading
ansible-playbook playbooks/kubernetes-install.yaml \
  -i inventory/hosts \
  -m debug -a "msg={{ azure_client_id }}" \
  -t cloud-provider
```

## Security Best Practices

1. **Credentials Management**:
   - Never commit credentials to Git
   - Use environment variables or vault
   - Store secrets in Kubernetes secrets only

2. **RBAC**:
   - Cloud provider runs with minimal required permissions
   - ClusterRole limited to necessary resources
   - ServiceAccount scoped to kube-system namespace

3. **Network Security**:
   - Load balancer security groups properly configured
   - Network policies for pod-to-pod communication
   - API server access restricted

4. **Secret Rotation**:
   - Rotate cloud provider credentials regularly
   - Update Kubernetes secrets after credential change
   - Monitor access logs for suspicious activity

## Performance Considerations

- **DaemonSet**: Runs on all control planes for HA
- **Resource Requests**: 100m CPU, 100Mi memory (tunable)
- **Wait Timeouts**: 300 seconds (configurable)
- **Load Balancer**: Standard SKU for production (Premium for higher throughput)

## References

- [Azure Cloud Provider for Kubernetes](https://github.com/kubernetes-sigs/cloud-provider-azure)
- [AWS Cloud Provider](https://github.com/kubernetes-sigs/aws-cloud-controller-manager)
- [GCP Cloud Provider](https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver)
- [Kubernetes Cloud Providers](https://kubernetes.io/docs/concepts/cloud-controller-manager/)

## Support

For cloud provider specific issues:

1. **Azure**: Check `azure-cloud-provider` secret and CCM logs
2. **AWS**: Follow implementation guide and create provider-specific tasks
3. **GCP**: Follow implementation guide and create provider-specific tasks

Enable debug logging:

```bash
ansible-playbook playbooks/kubernetes-install.yaml \
  -e "deployment_type=azure" \
  -t cloud-provider -vvv
```

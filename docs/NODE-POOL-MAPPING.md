# Node Pool Mapping Reference

Quick reference for node pool configurations and workload scheduling.

## Node Pool Summary Table

| Pool | Count | Machine Type | vCPU | RAM | OS Disk | Data Disks | Taints | Primary Label | Workloads |
|------|-------|--------------|------|-----|---------|-----------|--------|---------------|-----------|
| **control-plane** | 1/3/5 | D4s_v5 | 4 | 16GB | 100-150GB | None | `control-plane:NoSchedule` | None | Kubernetes API, etcd, scheduler |
| **system** | 1-2 | D8s_v5 | 8 | 32GB | 100-150GB | None | None | `kubernetes.azure.com/mode=system` | DNS, metrics, CNI, ingress |
| **cas** | 1-4 | E16s_v5+ | 16+ | 128GB+ | 100-200GB | 2-4x512GB-1TB | `cas:NoSchedule` | `workload.sas.com/class=cas` | SAS CAS analytics |
| **generic** | 2-10+ | D16s_v5 | 16 | 64GB | 100-200GB | 1-2x256-512GB | None | Configurable | Apps, compute, stateless |

## Recommended Configurations

### Development/Test (3 nodes, ~44 vCPU, 112 GB)
```hcl
control_plane = {count=1, D2s_v5, 50GB, no disks}
system        = {count=1, D2s_v5, 50GB, no disks}
generic       = {count=1, D4s_v5, 100GB, 256GB disk}
```
**Cost:** $$$ (minimal)  
**Capacity:** Very limited, development only

### Production Standard (11 nodes, ~92 vCPU, 352 GB)
```hcl
control_plane = {count=3, D4s_v5, 150GB, no disks}
system        = {count=2, D8s_v5, 150GB, no disks}
cas           = {count=2, E20s_v5, 200GB, 2x500GB disks}
generic       = {count=4, D16s_v5, 200GB, 512GB disk}
```
**Cost:** $$$$ (moderate)  
**Capacity:** 2-4 concurrent SAS Viya deployments

### Production HA (17 nodes, ~148 vCPU, 592 GB)
```hcl
control_plane = {count=5, D4s_v5, 150GB, no disks}       # Multi-zone if available
system        = {count=3, D8s_v5, 150GB, no disks}       # Multi-zone
cas           = {count=4, E20s_v5, 200GB, 2x500GB}       # Scale-out
generic       = {count=5, D16s_v5, 200GB, 512GB disk}    # Horizontal scale
```
**Cost:** $$$$$ (premium)  
**Capacity:** Production SLA, fault tolerance

## Workload to Node Pool Mapping

### SAS Viya Core Services

| Service | Node Pool | Selector/Taint | Notes |
|---------|-----------|----------------|-------|
| SAS CAS (cas) | cas | Must have `workload.sas.com/class=cas` | Memory-intensive, dedicated pool |
| SAS Compute (compute) | generic | Prefer `compute-profile=high-cpu` | Can share with other workloads |
| SAS Programming Runtime | generic | No special requirements | Colocates with compute |
| SAS Model Manager | generic | Prefers persistent storage nodes | Can scale horizontally |
| SAS Visual Analytics | generic | Moderate CPU/memory needs | Web-facing, load balance |

### Kubernetes Infrastructure

| Service | Node Pool | Constraints | Notes |
|---------|-----------|-------------|-------|
| API Server | control-plane | Must run on control-plane | System toleration automatic |
| etcd | control-plane | Must run on control-plane | Lifecycle tied to API server |
| kube-scheduler | control-plane | Must run on control-plane | Single scheduler per cluster |
| coredns | system | `kubernetes.azure.com/mode=system` | DNS for all pods |
| kube-proxy | All nodes | DaemonSet, all nodes | Network proxy |
| Calico (CNI) | All nodes | DaemonSet, all nodes | Network policies |
| Metrics-server | system | `kubernetes.azure.com/mode=system` | Pod resource metrics |

### Service Tiers

#### Tier 1: System Services (Auto-Tolerate System Label)
- CoreDNS
- kube-proxy
- Metrics-server
- Ingress controller

#### Tier 2: CAS Workloads (Requires Specific Toleration)
- SAS CAS (cas)
- CAS controller pod

#### Tier 3: General Applications (No Taints Required)
- SAS Compute (compute)
- SAS Viya applications
- User-deployed services

## Label Usage Guide

### Standard Kubernetes Labels (Read-Only)
```yaml
kubernetes.io/hostname: <node-hostname>        # Node name
kubernetes.io/os: linux                        # OS type
node.kubernetes.io/instance-type: <vm-size>    # Azure VM size
topology.kubernetes.io/region: <region>        # Azure region
topology.kubernetes.io/zone: <zone>            # Availability zone
```

### SAS-Specific Labels (Configurable)

**Primary Workload Classification:**
```yaml
workload.sas.com/class: cas|compute|stateless|stateful|other
```

**Secondary Optimization:**
```yaml
workload.sas.com/compute-class: in-memory|batch|streaming|generic
```

**Resource Size (Optional):**
```yaml
compute-profile: high-cpu|high-memory|balanced|gpu-ready
```

**Example Node Label Set:**
```yaml
workload.sas.com/class: cas
workload.sas.com/compute-class: in-memory
compute-profile: high-memory
kubernetes.azure.com/mode: system  # (only for system pool)
```

## Taint/Toleration Patterns

### Pattern 1: CAS Exclusivity
**Taint Applied:** `workload.sas.com/class=cas:NoSchedule`

**Toleration Required:**
```yaml
tolerations:
  - key: workload.sas.com/class
    operator: Equal
    value: cas
    effect: NoSchedule
```

**Who Gets In:** Only pods with matching toleration

### Pattern 2: Control Plane Exclusivity
**Taint Applied:** `node-role.kubernetes.io/control-plane:NoSchedule`

**Toleration (Automatic):** System pods have automatic toleration

**Who Gets In:** Only system pods and pods with explicit toleration

### Pattern 3: No Taints (Generic Pool)
**Taints:** None applied

**Access:** Any pod can schedule here

**Who Gets In:** Everything without a more specific destination

## Auto-Scaling Considerations

### Node Count Targets by Workload

| Workload Size | Control Plane | System | CAS | Generic | Total |
|---|---|---|---|---|---|
| Dev/Test | 1 | 1 | 0 | 1-2 | 3-4 |
| Small Prod | 3 | 2 | 1 | 3 | 9 |
| Large Prod | 3 | 2 | 2-4 | 5-8 | 12-17 |
| Enterprise | 5 | 3 | 4-8 | 8-15 | 20-31 |

### Scaling Guidelines

1. **Control Plane:** Scale 1→3→5 for HA (use kube-vip for multi-master)
2. **System:** Scale 1→2→3 for redundancy
3. **CAS:** Scale 1→2→4 (vertical then horizontal)
4. **Generic:** Scale 2→5→10→20+ freely (horizontal scaling)

## Terraform Variable Reference

### Basic Configuration
```hcl
# Enable/disable node pools
node_pools = {
  control_plane = { count=1, machine_type="...", ... }
  system = { ... }
  cas = { ... }
  generic = { ... }
}

# Infrastructure VMs
create_jump = true
create_nfs = true
jump_machine_type = "Standard_B2s"
nfs_machine_type = "Standard_D4s_v5"
```

### Advanced Options
```hcl
# Networking
azure_accelerated_networking = true  # Enable for better performance

# Kubernetes
node_pool_defaults = {
  count = 1
  machine_type = "Standard_D4s_v5"
  os_disk = 100
  data_disks = []
  node_taints = []
  node_labels = {}
}

# Pod Scheduling
enable_pod_disruption_budget = true
enable_node_affinity_labels = true
```

## Terraform Outputs

After `terraform apply`, use these outputs:

```hcl
output "node_pools_summary"     # Full node pool configuration
output "node_selector_labels"   # Labels for pod selectors
output "node_taints_by_pool"    # Taints per pool
output "kubernetes_nodes"       # Node info for provisioning
```

## Ansible Integration

Node pool information flows to Ansible for:
1. **Host Grouping:** Group hosts by node pool
2. **Variable Assignment:** Set playbook vars per pool
3. **Service Placement:** Deploy services to correct nodes

Example Ansible groups:
```yaml
[k8s_control_plane]
k8s-cp-1 node_class=control_plane
k8s-cp-2 node_class=control_plane
k8s-cp-3 node_class=control_plane

[k8s_system]
k8s-system-1 node_class=system
k8s-system-2 node_class=system

[k8s_cas]
k8s-cas-1 node_class=cas node_taints=workload.sas.com/class=cas

[k8s_workers]
k8s-generic-1 node_class=generic
k8s-generic-2 node_class=generic
```

## Migration Checklist

Before changing node pool configuration:

- [ ] Review current capacity: `kubectl top nodes`
- [ ] Plan new node pool sizes
- [ ] Create new nodes with Terraform
- [ ] Verify new nodes RegisteredReady
- [ ] Drain old nodes: `kubectl drain <node>`
- [ ] Remove old nodes: `kubectl delete node <node>`
- [ ] Destroy old nodes with Terraform
- [ ] Verify workloads rescheduled correctly

## Troubleshooting Decision Tree

**Pods Pending?**
- Yes → Check: Node affinity, taints/tolerations, resources
- No → Pod running or unknown state

**Node NotReady?**
- Check kubelet: `systemctl status kubelet`
- Check network: `ping -c 4 <node-ip>`
- Check disk: `df -h` for full disks

**Uneven Load Distribution?**
- Review: Pod affinity rules, node selectors
- Solution: Use pod anti-affinity or topology spread constraints

**Performance Issues**
- Check: Node CPU/memory utilization
- Review: Pod resource requests vs actual usage
- Solution: Right-size requests or add more nodes

---

**Last Updated:** PSCLOUD-771 (April 14, 2026)  
**Related:** WORKER-NODES.md, sample-terraform-azure.tfvars, examples/

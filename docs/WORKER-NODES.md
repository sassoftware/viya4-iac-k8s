# Azure Kubernetes Worker Node Configuration

## Overview

Worker nodes are the workhorses of your Kubernetes cluster. This guide covers how to configure different worker node types, apply labels and taints, and optimize resource allocation for SAS Viya deployments.

## Node Pool Architecture

### Control Plane Nodes
- **Purpose:** Run Kubernetes API server, etcd, scheduler, controller-manager
- **Quantity:** Odd number (1, 3, 5...) for HA with kube-vip
- **Recommended Size:** Standard_D4s_v5 (4 vCPU, 16 GB RAM)
- **Default Taint:** `node-role.kubernetes.io/control-plane:NoSchedule`
- **Use Case:** Core Kubernetes infrastructure only

### System Nodes
- **Purpose:** System workloads - DNS (CoreDNS), metrics-server, CNI (Calico), ingress controller
- **Quantity:** 1-2 nodes (isolated from application workloads)
- **Recommended Size:** Standard_D8s_v5 (8 vCPU, 32 GB RAM)
- **Required Label:** `kubernetes.azure.com/mode=system`
- **Taints:** None (all system pods have automatic toleration)
- **Use Case:** Kubernetes infrastructure services

### CAS Nodes (Analytics)
- **Purpose:** SAS Compute and Analytical Services for in-memory computing
- **Quantity:** 1-2+ nodes depending on data size
- **Recommended Size:** Standard_E16s_v5 or larger (memory-optimized)
  - E16s_v5: 16 vCPU, 128 GB RAM
  - E20s_v5: 20 vCPU, 160 GB RAM
  - E32s_v5: 32 vCPU, 256 GB RAM
- **Data Disks:** 2-4 disks (512GB-1TB each) for memory spill
- **Taint:** `workload.sas.com/class=cas:NoSchedule`
- **Label:** `workload.sas.com/class=cas`
- **Use Case:** In-memory analytics, SAS CAS workloads only

### Generic Worker Nodes
- **Purpose:** General purpose workloads - compute jobs, stateless apps, caching services
- **Quantity:** 2-10+ nodes (scales horizontally)
- **Recommended Size Options:**
  - General: Standard_D16s_v5 (16 vCPU, 64 GB)
  - High CPU: Standard_D32s_v5 (32 vCPU, 128 GB)
  - High Memory: Standard_E16s_v5 (16 vCPU, 128 GB)
- **Data Disks:** 1-2 disks (256-512GB) for OS and container caching
- **Taints:** None (accepts any workload without specific requirements)
- **Labels:** User-configurable based on workload class
- **Use Case:** Application containers, compute workloads, microservices

## Kubernetes Labels Reference

### Azure-Provided Labels
```hcl
"kubernetes.io/hostname"              # Node hostname (auto-assigned)
"kubernetes.io/os"                    # OS type: linux, windows
"node.kubernetes.io/instance-type"    # Azure VM size
"topology.kubernetes.io/region"       # Azure region
"topology.kubernetes.io/zone"         # Azure availability zone
```

### SAS Workload Classification Labels
```hcl
"workload.sas.com/class"              # Workload type: cas, compute, stateless, stateful
"workload.sas.com/compute-class"      # Optimization: in-memory, batch, streaming
"launcher.sas.com/prepullImage"       # Pre-pull image: sas-programming-environment, etc.
"node.kubernetes.io/purpose"          # Node purpose: infrastructure, apps, analytics
```

### Custom Scheduling Labels
```hcl
"compute-profile"                     # Hardware profile: high-cpu, high-memory, balanced
"storage-tier"                        # Storage type: ssd, hdd, nvme
"gpu-ready"                          # GPU capability: true/false
"node-role.kubernetes.io/type"        # Node type: control-plane, system, worker
"sas.com/node-class"                 # Additional SAS classification
```

## Kubernetes Taints Reference

### Standard Kubernetes Taints
```
node-role.kubernetes.io/control-plane:NoSchedule
  Applied to: Control plane nodes
  Effect: Prevents regular application pods (system pods tolerate automatically)
  
node-role.kubernetes.io/master:NoSchedule
  Applied to: Legacy control plane nodes (deprecated)
  Effect: Prevents pod scheduling
```

### SAS Workload Taints
```
workload.sas.com/class=cas:NoSchedule
  Applied to: CAS worker nodes
  Effect: Only pods with specific toleration can be scheduled
  Purpose: Isolate CAS workloads to dedicated memory-optimized nodes
  
workload.sas.com/class=compute:NoSchedule
  Applied to: Compute-specific worker pools
  Effect: Routes compute jobs to dedicated nodes
  Purpose: Prevents resource contention with other workload types
```

## Configuration Examples

### Example 1: Small Development Cluster (3 nodes)
```hcl
node_pools = {
  control_plane = {
    count        = 1
    machine_type = "Standard_D2s_v5"      # 2 vCPU, 8 GB
    os_disk      = 50
    data_disks   = []
    node_taints  = ["node-role.kubernetes.io/control-plane:NoSchedule"]
    node_labels  = {}
  },
  system = {
    count        = 1
    machine_type = "Standard_D2s_v5"      # 2 vCPU, 8 GB
    os_disk      = 50
    data_disks   = []
    node_taints  = []
    node_labels  = {"kubernetes.azure.com/mode" = "system"}
  },
  generic = {
    count        = 1
    machine_type = "Standard_D4s_v5"      # 4 vCPU, 16 GB
    os_disk      = 100
    data_disks   = [256]
    node_taints  = []
    node_labels  = {}
  }
}
```

### Example 2: Production HA Cluster (11 nodes)
```hcl
node_pools = {
  control_plane = {
    count        = 3                      # HA with kube-vip
    machine_type = "Standard_D4s_v5"
    os_disk      = 150
    data_disks   = []
    node_taints  = ["node-role.kubernetes.io/control-plane:NoSchedule"]
    node_labels  = {}
  },
  system = {
    count        = 2
    machine_type = "Standard_D8s_v5"
    os_disk      = 150
    data_disks   = []
    node_taints  = []
    node_labels  = {
      "kubernetes.azure.com/mode" = "system"
      "node.kubernetes.io/purpose" = "infrastructure"
    }
  },
  cas = {
    count        = 2
    machine_type = "Standard_E20s_v5"     # 20 vCPU, 160 GB RAM (memory-optimized)
    os_disk      = 200
    data_disks   = [500, 500]             # 2x500GB for memory spill
    node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels  = {
      "workload.sas.com/class"         = "cas"
      "workload.sas.com/compute-class" = "in-memory"
    }
  },
  generic = {
    count        = 4
    machine_type = "Standard_D16s_v5"     # 16 vCPU, 64 GB RAM
    os_disk      = 200
    data_disks   = [512]
    node_taints  = []
    node_labels  = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  }
}
```

### Example 3: Specialized Workload Pools
```hcl
node_pools = {
  control_plane = {
    count        = 1
    machine_type = "Standard_D4s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = ["node-role.kubernetes.io/control-plane:NoSchedule"]
    node_labels  = {}
  },
  system = {
    count        = 1
    machine_type = "Standard_D8s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = []
    node_labels  = {"kubernetes.azure.com/mode" = "system"}
  },
  
  # In-memory analytics
  cas = {
    count        = 2
    machine_type = "Standard_E32s_v5"     # 32 vCPU, 256 GB RAM
    os_disk      = 200
    data_disks   = [1000, 1000]           # 2x1TB for large datasets
    node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels  = {
      "workload.sas.com/class"       = "cas"
      "compute-profile"              = "high-memory"
    }
  },
  
  # High CPU compute
  compute = {
    count        = 3
    machine_type = "Standard_D32s_v5"     # 32 vCPU, 128 GB RAM
    os_disk      = 200
    data_disks   = [512]
    node_taints  = ["workload.sas.com/class=compute:NoSchedule"]
    node_labels  = {
      "workload.sas.com/class" = "compute"
      "compute-profile"        = "high-cpu"
    }
  },
  
  # Stateless/web services
  stateless = {
    count        = 2
    machine_type = "Standard_D8s_v5"      # 8 vCPU, 32 GB RAM
    os_disk      = 150
    data_disks   = [256]
    node_taints  = []
    node_labels  = {
      "workload.sas.com/class" = "stateless"
      "node-role"              = "web-services"
    }
  }
}
```

## Pod Scheduling Patterns

### Pattern 1: NodeSelector (Simple Scheduling)
Best for: Simple workload-to-node mapping

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cas-workload
spec:
  nodeSelector:
    workload.sas.com/class: cas
  containers:
    - name: cas
      image: sas-cas:latest
```

### Pattern 2: Node Affinity (Flexible Scheduling)
Best for: Complex scheduling requirements, preferred vs required

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sas-compute
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: workload.sas.com/class
                    operator: In
                    values: [compute]
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: compute-profile
                    operator: In
                    values: [high-cpu]
      tolerations:
        - key: workload.sas.com/class
          operator: Equal
          value: compute
          effect: NoSchedule
      containers:
        - name: compute
          image: sas-compute:latest
          resources:
            requests:
              cpu: "8"
              memory: "32Gi"
```

### Pattern 3: Pod Disruption Budgets (High Availability)
Best for: Critical workloads that need uptime guarantees

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: cas-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      workload: cas
```

## Migration Between Node Pools

### Scale New Pool While Draining Old
```bash
# 1. Increase new worker node count
#    Edit tfvars: generic.count = 10

# 2. Apply Terraform
terraform apply

# 3. Wait for new nodes to be ready
kubectl get nodes -L workload.sas.com/class

# 4. Drain old nodes
kubectl drain <old-node> --ignore-daemonsets --delete-emptydir-data

# 5. Delete old nodes
kubectl delete node <old-node>

# 6. Reduce old node count in Terraform
```

## Monitoring Node Health

### Check Node Status
```bash
# List all nodes with labels
kubectl get nodes --show-labels

# Describe specific node
kubectl describe node <node-name>

# Check node resource usage
kubectl top nodes
```

### Common Node Issues

**Pod Pending Due to Node Selector:**
```bash
kubectl describe pod <pod-name>
# Look for: "no node matched the specified node selector"

# Solution: Either match labels or adjust node selector
kubectl get nodes --show-labels
```

**Pod Evicted from Node:**
```bash
# Caused by: disk/memory pressure
kubectl describe pod <pod-name>

# Solution: 
# - Add more nodes
# - Reduce pod resources
# - Increase node resource allocation
```

**Node NotReady:**
```bash
# Status: NotReady
kubectl describe node <node-name>

# Solution:
# - Check kubelet status on node
# - Verify network connectivity
# - Check disk space: df -h
```

## Best Practices

1. **Dedicated Pools for Pinned Workloads**
   - Use separate node pools with taints for CAS and specialized workloads
   - Prevents resource contention and ensures predictable performance

2. **Resource Requests**
   - Always set CPU/memory requests in pod specs
   - Helps scheduler place pods on appropriate nodes
   - Use quality-of-service (QoS) classes correctly

3. **Node Affinity Labels**
   - Use meaningful label names: `compute-profile`, `storage-tier`, etc.
   - Document custom labels in your cluster documentation
   - Keep labels consistent across environments

4. **Taint Strategy**
   - Apply taints only when you need exclusive node access
   - Use `NoSchedule` for workload isolation (not `NoExecute`)
   - Document taint strategy for operations team

5. **Scaling Strategy**
   - Scale generic workers horizontally (simple)
   - Scale CAS vertically (bigger nodes) or multiple smaller nodes
   - Monitor resource usage to right-size nodes

6. **Data Disk Planning**
   - CAS nodes: 2+ disks for memory spill and fault tolerance
   - Stateful nodes: 2+ disks for data replication
   - Stateless nodes: 1 disk sufficient (OS + container cache)

7. **High Availability**
   - Control Plane: 3+ nodes for HA with kube-vip
   - System: 2+ nodes for service redundancy
   - Service pods: Set PodDisruptionBudgets for multi-zone resilience

## Troubleshooting Examples

### Scenario: CAS Pod Won't Schedule
**Problem:** Pod pending on CAS-specific workload

```bash
# 1. Check if CAS nodes exist
kubectl get nodes -l workload.sas.com/class=cas

# 2. Check node taints
kubectl describe node <cas-node> | grep Taints

# 3. Check pod toleration
kubectl get pod <pod-name> -o yaml | grep -A3 tolerations

# 4. If toleration missing, add:
tolerations:
  - key: workload.sas.com/class
    operator: Equal
    value: cas
    effect: NoSchedule
```

### Scenario: Node Resource Exhaustion
**Problem:** New pods pending even with spare nodes

```bash
# 1. Check node capacity
kubectl top nodes
kubectl describe nodes

# 2. Check pod resource requests
kubectl get pods --all-namespaces -o json | jq '.items[].spec.containers[].resources.requests'

# 3. Solution options:
#    a) Add more nodes (horizontal scaling)
#    b) Reduce pod resource requests
#    c) Scale down lower-priority workloads
```

### Scenario: Uneven Load Distribution
**Problem:** Some workers heavily loaded, others empty

```bash
# 1. Check pod distribution
kubectl get pods -o wide

# 2. Check node affinity rules
kubectl get pods -o yaml | grep -A10 affinity

# 3. Solution:
#    Consider pod anti-affinity to spread workloads
#    Or use topology spread constraints
```

## Next Steps

- Review [Node Pool Mapping](NODE-POOL-MAPPING.md) for deployment reference
- Examine example tfvars configurations in `examples/azure/`
- Configure pod scheduling preferences in your application manifests
- Set up monitoring and alerts for node health

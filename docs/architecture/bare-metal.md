# Bare Metal Topology Architecture

[← Architecture Overview](overview.md) | [Deployment Guide →](../../topologies/bare_metal/README.md)

## Overview

The bare metal topology has **no Terraform-managed infrastructure**. You supply pre-existing physical machines or VMs. Terraform's sole role is to write the Ansible `inventory` and `ansible-vars.yaml` files from the variables you provide.

```mermaid
flowchart LR
    YOU(["Operator — bring your own hosts"])

    YOU -->|"provide IPs"| TF["terraform apply
    (generates files only)"]
    TF --> INV["inventory file"]
    TF --> AVARS["ansible-vars.yaml"]

    INV & AVARS --> ANS_SYS["ansible-playbook
    systems-install.yaml"]
    ANS_SYS --> ANS_K8S["ansible-playbook
    kubernetes-install.yaml"]
    ANS_K8S --> K8S(["Kubernetes Cluster"])
```

## Host Requirements Layout

```mermaid
graph TD
    CLUSTER["Kubernetes Cluster"]

    CLUSTER --> CP["Control Plane Nodes × 3 minimum
    [k8s_control_plane] in inventory
    Ubuntu 22.04 / 24.04"]

    CLUSTER --> WN["Worker Nodes × 6 minimum
    [k8s_node] in inventory
    labelled with workload.sas.com/class"]

    JUMP["Jump Server
    [jump] in inventory
    optional — provides bastion access"]

    NFS["NFS Server
    [nfs] in inventory
    backing store for default StorageClass"]

    PG["PostgreSQL Server
    [postgres] in inventory
    optional — omit for in-cluster PG"]

    CLUSTER --- JUMP
    CLUSTER --- NFS
    CLUSTER --- PG
```

## Node Roles and Recommended Resources

| Role | Inventory Group | Min Count | Recommended CPUs | Recommended Memory |
| :--- | :--- | :--- | :--- | :--- |
| Control Plane | `[k8s_control_plane]` | 3 | 4 | 8 GB |
| System | `[k8s_node]` | 1 | 4 | 8 GB |
| Stateless | `[k8s_node]` | 2 | 8 | 32 GB |
| Stateful | `[k8s_node]` | 2 | 8 | 32 GB |
| CAS | `[k8s_node]` | 2+ | 16 | 64 GB |
| Jump | `[jump]` | 1 | 2 | 4 GB |
| NFS | `[nfs]` | 1 | 4 | 8 GB |
| PostgreSQL | `[postgres]` | 0–1 | 4 | 16 GB |

## Networking Requirements

```mermaid
graph LR
    NET["Routable Network
    all hosts reachable by each other"]

    NET --> VIP_IP["Static IP — cluster VIP
    kubernetes_vip_ip / kubernetes_vip_fqdn"]
    NET --> LB_IP["Static IP(s) — load balancer
    kubernetes_loadbalancer_addresses"]
    NET --> NODE_IPS["Static IP per node
    listed in inventory"]
```

| Requirement | Detail |
| :--- | :--- |
| OS | Ubuntu 22.04 LTS or 24.04 LTS |
| User | Password-less `sudo` on all hosts |
| Network | Single routable network spanning all hosts |
| SSH | Public keys from `system_ssh_keys_dir` distributed to all hosts |
| VIP | At least 1 static IP for `kubernetes_vip_ip` |
| LB IPs | At least 1 CIDR block or IP range for `kubernetes_loadbalancer_addresses` |
| NFS disk | Sufficient storage on the NFS server for SAS Viya PVCs |
| Local disks | Empty partitions on stateful/CAS nodes for `local-storage` StorageClass |

## Inventory File Structure

```ini
# topologies/bare_metal/sample-inventory

[k8s_control_plane]
<control-plane-1-ip>
<control-plane-2-ip>
<control-plane-3-ip>

[k8s_node]
<worker-1-ip>    node_labels="workload.sas.com/class=stateless"
<worker-2-ip>    node_labels="workload.sas.com/class=stateful"
<worker-3-ip>    node_labels="workload.sas.com/class=cas"
...

[jump]
<jump-ip>

[nfs]
<nfs-ip>

[postgres]   # optional
<postgres-ip>
```

## Script Entry Point

```bash
export $(grep -v '^#' ~/.bare_metal_creds.env | xargs)

# apply writes inventory + ansible-vars.yaml only (no VM provisioning)
./scripts/oss-k8s.sh apply    --system bare_metal --workspace /workspace --tfvars /workspace/bm.tfvars
./scripts/oss-k8s.sh install  --system bare_metal --workspace /workspace
./scripts/oss-k8s.sh uninstall --system bare_metal --workspace /workspace
```

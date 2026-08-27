# OpenStack Topology Architecture

[← Architecture Overview](overview.md) | [Deployment Guide →](../../topologies/openstack/README.md)

## Resource Layout

```mermaid
graph TD
    OS_CLOUD["OpenStack Cloud"]
    OS_CLOUD --> NOVA["Nova (Compute)"]
    OS_CLOUD --> NEUTRON["Neutron (Network)"]
    OS_CLOUD --> CINDER["Cinder (Block Storage)"]
    OS_CLOUD --> GLANCE["Glance (Image)"]

    NEUTRON --> NET["Project Network
    openstack_network_name"]
    NEUTRON --> FIP_POOL["Floating IP Pool
    openstack_floating_ip_pool"]

    FIP_POOL --> VIP_FIP["VIP Floating IP
    → cluster_vip_ip
    (control-plane HA)"]
    FIP_POOL --> LB_FIP["LB Floating IP
    → cluster_lb_addresses
    (service load balancer)"]

    NET --> ROUTER["Router / NAT Gateway
    nat_ip"]

    NOVA --> CP["Control Plane VMs × 3
    kube-vip on VIP_FIP"]
    NOVA --> WN["Worker VMs
    system · stateless · stateful
    cas · compute"]
    NOVA --> JUMP["Jump Server VM
    (optional)"]
    NOVA --> NFS["NFS Server VM
    (optional)"]
    NOVA --> CR["Container Registry VM
    Harbor (optional)"]

    CP --> VIP_FIP
    GLANCE --> CP & WN
    CINDER --> NFS
```

## Networking Design

| Component | Detail |
| :--- | :--- |
| Network | All VMs attach to `openstack_network_name` (Neutron network) |
| Floating IPs | Pre-allocated from `openstack_floating_ip_pool` before `terraform apply` |
| Control-plane VIP | One floating IP assigned to kube-vip as the control-plane virtual IP |
| Service LB | Second floating IP + `cluster_lb_addresses` range for kube-vip cloud provider / MetalLB |
| Security groups | `openstack_security_groups` applied to every VM |
| Port allowed-address-pairs | Patched post-apply to allow kube-vip VIP traffic through Neutron port security |
| Keypair | `openstack_ssh_keypair` must exist in OpenStack before deployment |

## VIP and Floating IP Allocation Flow

```mermaid
sequenceDiagram
    participant OP as Operator
    participant SCR as scripts/oss-k8s.sh
    participant OS as OpenStack API
    participant TF as Terraform

    OP->>SCR: oss-k8s.sh apply
    SCR->>OS: allocate_vip_floating_ip()
    OS-->>SCR: VIP IP + LB IP
    SCR->>TF: terraform apply -var cluster_vip_ip=... -var cluster_lb_addresses=...
    TF-->>SCR: inventory + ansible-vars.yaml
    SCR->>OS: patch_vip_allowed_pairs() — neutron port-update
```

## Availability Zone Placement

```mermaid
graph LR
    AZ["openstack_availability_zone"]
    AZ --> CP1 & CP2 & CP3
    AZ --> WN["Worker VMs"]
```

All VMs are placed in the same availability zone (`openstack_availability_zone`). For multi-AZ deployments, additional topology customization is needed.

## Script Entry Point

```bash
source ~/.openstack_creds.env

./scripts/oss-k8s.sh apply    --system openstack --workspace /workspace --tfvars /workspace/openstack.tfvars
./scripts/oss-k8s.sh install  --system openstack --workspace /workspace
./scripts/oss-k8s.sh destroy  --system openstack --workspace /workspace
```

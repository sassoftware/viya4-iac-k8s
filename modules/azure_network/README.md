# Azure Network Module

Terraform module for creating Azure networking infrastructure for self-managed Kubernetes deployments.

## Overview

This module creates or manages Azure networking resources required for deploying Kubernetes on Azure VMs, including:

- Virtual Network (VNet)
- Subnets
- Network Security Group (NSG)
- Kubernetes-specific NSG rules

## Features

- **Flexible VNet Management**: Create new VNet or use existing one
- **Subnet Configuration**: Create multiple subnets or use existing ones
- **Kubernetes NSG Rules**: Automatically configures security rules for all required Kubernetes ports
- **Bring Your Own Network (BYO)**: Full support for existing networking infrastructure
- **Custom DNS**: Optional custom DNS server configuration

## Usage

### Basic Usage (New Network)

```hcl
module "azure_network" {
  source = "./modules/azure_network"

  prefix              = "my-k8s"
  resource_group_name = azurerm_resource_group.main.name
  location            = "eastus"
  
  vnet_address_space = ["192.168.0.0/16"]
  
  subnets = {
    k8s = {
      prefixes          = ["192.168.0.0/22"]
      service_endpoints = []
    }
    misc = {
      prefixes          = ["192.168.4.0/24"]
      service_endpoints = []
    }
  }
  
  ssh_source_cidrs        = ["203.0.113.0/24"]
  api_server_source_cidrs = ["203.0.113.0/24"]
  
  tags = {
    environment = "production"
    managed_by  = "terraform"
  }
}
```

### Using Existing Network (BYO Network)

```hcl
module "azure_network" {
  source = "./modules/azure_network"

  prefix              = "my-k8s"
  resource_group_name = azurerm_resource_group.main.name
  location            = "eastus"
  
  # Use existing VNet
  vnet_name                = "my-existing-vnet"
  vnet_resource_group_name = "my-network-rg"
  vnet_address_space       = ["10.0.0.0/16"]  # Required but not used for existing VNet
  
  # Use existing subnets
  existing_subnet_names = {
    k8s  = "kubernetes-subnet"
    misc = "infrastructure-subnet"
  }
  
  subnets = {}  # Empty when using existing subnets
  
  # Use existing NSG without creating new rules
  nsg_name           = "my-existing-nsg"
  create_nsg_rules   = false
  
  ssh_source_cidrs        = ["203.0.113.0/24"]
  api_server_source_cidrs = ["203.0.113.0/24"]
  
  tags = {}
}
```

## Kubernetes Ports and NSG Rules

This module automatically configures NSG rules for the following Kubernetes ports:

| Port Range | Protocol | Purpose | Access Level | Priority |
|------------|----------|---------|--------------|----------|
| 22 | TCP | SSH to VMs | Restricted by `ssh_source_cidrs` | 100 |
| 6443 | TCP | Kubernetes API Server | Restricted by `api_server_source_cidrs` | 110 |
| 10250 | TCP | Kubelet API | Internal VNet only | 120 |
| 10256 | TCP | kube-proxy health checks | Internal VNet only | 130 |
| 5473 | TCP | Calico Typha (CNI) | Internal VNet only | 140 |
| 179 | TCP | BGP (Calico routing) | Internal VNet only | 150 |
| 2379-2380 | TCP | etcd server | Internal VNet only | 160 |
| 30000-32767 | TCP | NodePort Services | Restricted by `nodeport_source_cidrs` (optional) | 170 |

**Security Note**: Ports marked as "Internal VNet only" use Azure's `VirtualNetwork` service tag and cannot be accessed from the internet.

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| prefix | Prefix for resource naming | string | n/a | yes |
| resource_group_name | Resource group name | string | n/a | yes |
| location | Azure region | string | n/a | yes |
| vnet_name | Name of existing VNet (null to create new) | string | null | no |
| vnet_resource_group_name | Resource group of existing VNet | string | null | no |
| vnet_address_space | VNet address space | list(string) | n/a | yes |
| dns_servers | Custom DNS servers | list(string) | [] | no |
| subnets | Map of subnets to create | map(object) | n/a | yes |
| existing_subnet_names | Map of existing subnet names | map(string) | {} | no |
| nsg_name | Name of existing NSG | string | null | no |
| create_nsg_rules | Create Kubernetes NSG rules | bool | true | no |
| ssh_source_cidrs | CIDRs for SSH access | list(string) | n/a | yes |
| api_server_source_cidrs | CIDRs for K8s API access | list(string) | n/a | yes |
| nodeport_source_cidrs | CIDRs for NodePort access | list(string) | [] | no |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | ID of the Virtual Network |
| vnet_name | Name of the Virtual Network |
| vnet_address_space | Address space of the VNet |
| subnet_ids | Map of subnet names to IDs |
| subnet_details | Full subnet details (id, name, address_prefixes) |
| nsg_id | ID of the Network Security Group |
| nsg_name | Name of the Network Security Group |

## Network Planning Guidelines

### VNet Size Recommendations

- **Small cluster** (< 20 nodes): `/20` or `/16` (4096-65536 IPs)
- **Medium cluster** (20-100 nodes): `/16` (65536 IPs)
- **Large cluster** (100+ nodes): `/12` or larger (1M+ IPs)

### Subnet Size Recommendations

**k8s subnet** (for Kubernetes nodes):
- Small: `/22` (1024 IPs)
- Medium: `/20` (4096 IPs)
- Large: `/18` or larger (16384+ IPs)

**misc subnet** (for jump box, NFS, etc.):
- Usually `/24` (256 IPs) is sufficient

## Security Best Practices

1. **Restrict SSH Access**: Only allow SSH from your management network
2. **Restrict API Access**: Limit Kubernetes API access to authorized networks
3. **Avoid NodePorts**: Use LoadBalancer or Ingress services instead when possible
4. **Use Private IPs**: For production, consider using private cluster endpoints
5. **Network Segmentation**: Use separate subnets for different workload types

## Requirements

- Terraform >= 1.10.0
- Azure Provider (~> 4.48)
- Appropriate Azure permissions to create networking resources

## Examples

See the [examples/azure](../../examples/azure/) directory for complete configuration examples.

## License

Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0

# Azure VM Module

This Terraform module creates and manages Azure Linux Virtual Machines for Kubernetes cluster nodes and infrastructure VMs (jump box, NFS server).

## Features

- **Flexible VM Configuration**: Support for any Azure VM size with customizable CPU, memory, and storage
- **Multiple Data Disks**: Attach multiple data disks of varying sizes for storage-intensive workloads
- **Network Integration**: Automatic network interface creation with optional public IP assignment
- **Security Group Association**: Optional NSG association for network access control
- **Cloud-Init Support**: Provision VMs with custom initialization scripts
- **Kubernetes-Aware**: Built-in support for Kubernetes node taints and labels
- **Accelerated Networking**: Optional accelerated networking for improved network performance
- **SSH Key Authentication**: Secure access via SSH public key (no passwords)

## Usage

### Basic Example - Single VM

```hcl
module "vm_control_plane" {
  source = "./modules/azure_vm"

  vm_name         = "k8s-cp-1"
  vm_size         = "Standard_D4s_v5"
  resource_group_name = azurerm_resource_group.main.name
  azure_location  = azurerm_resource_group.main.location
  subnet_id       = azurerm_subnet.k8s.id
  nsg_id          = azurerm_network_security_group.main.id
  ssh_public_key  = file("~/.ssh/id_rsa.pub")
  
  os_disk_size    = 100
  assign_public_ip = false
  
  node_taints = ["node-role.kubernetes.io/control-plane:NoSchedule"]
  node_labels = {}
  
  tags = {
    Environment = "production"
    Cluster     = "k8s-main"
  }
}
```

### Advanced Example - Worker Node with Data Disks

```hcl
module "vm_cas_worker" {
  source = "./modules/azure_vm"

  vm_name         = "k8s-cas-1"
  vm_size         = "Standard_E16s_v5"        # Memory-optimized for CAS
  resource_group_name = azurerm_resource_group.main.name
  azure_location  = azurerm_resource_group.main.location
  subnet_id       = azurerm_subnet.k8s.id
  nsg_id          = azurerm_network_security_group.main.id
  ssh_public_key  = file("~/.ssh/id_rsa.pub")
  
  # OS and data disk configuration
  os_disk_size    = 100
  data_disk_sizes = [512, 512]                # 2x512GB disks for memory spill
  
  assign_public_ip = false
  accelerated_networking = true               # Enable for better performance
  
  # Kubernetes configuration
  node_taints = ["workload.sas.com/class=cas:NoSchedule"]
  node_labels = {
    "workload.sas.com/class" = "cas"
  }
  
  tags = {
    Environment = "production"
    NodeType    = "cas"
  }
}
```

### Example - NFS Server with Multiple Storage Disks

```hcl
module "vm_nfs" {
  source = "./modules/azure_vm"

  vm_name         = "k8s-nfs-1"
  vm_size         = "Standard_D4s_v5"
  resource_group_name = azurerm_resource_group.main.name
  azure_location  = azurerm_resource_group.main.location
  subnet_id       = azurerm_subnet.misc.id
  nsg_id          = azurerm_network_security_group.main.id
  ssh_public_key  = file("~/.ssh/id_rsa.pub")
  
  # OS and storage configuration
  os_disk_size    = 100
  data_disk_sizes = [1024, 1024, 1024, 1024]  # 4x1TB for RAID1 configuration
  
  assign_public_ip = true                     # NFS may need external access
  accelerated_networking = true               # Better I/O performance
  
  # Cloud-init for NFS setup
  cloud_init_enabled = true
  cloud_init_script = templatefile("${path.module}/files/nfs-init.sh", {
    nfs_shares = "/export/viya"
  })
  
  tags = {
    Environment = "production"
    Role        = "nfs"
  }
}
```

### Multiple VMs Using for_each

```hcl
locals {
  worker_nodes = {
    cas = {
      machine_type = "Standard_E16s_v5"
      data_disks   = [512, 512]
      taints       = ["workload.sas.com/class=cas:NoSchedule"]
      labels       = {"workload.sas.com/class" = "cas"}
    }
    generic = {
      machine_type = "Standard_D16s_v5"
      data_disks   = [256]
      taints       = []
      labels       = {"workload.sas.com/class" = "compute"}
    }
  }
}

module "worker_vms" {
  for_each = local.worker_nodes
  
  source = "./modules/azure_vm"

  vm_name         = "k8s-${each.key}-1"
  vm_size         = each.value.machine_type
  resource_group_name = azurerm_resource_group.main.name
  azure_location  = azurerm_resource_group.main.location
  subnet_id       = azurerm_subnet.k8s.id
  nsg_id          = azurerm_network_security_group.main.id
  ssh_public_key  = file("~/.ssh/id_rsa.pub")
  
  os_disk_size    = 100
  data_disk_sizes = each.value.data_disks
  
  assign_public_ip = false
  accelerated_networking = true
  
  node_taints = each.value.taints
  node_labels = each.value.labels
  
  tags = {
    Environment = "production"
    NodePool    = each.key
  }
}
```

## Variables

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `vm_name` | string | Name of the virtual machine |
| `vm_size` | string | Azure VM size (e.g., Standard_D4s_v5) |
| `resource_group_name` | string | Azure resource group name |
| `azure_location` | string | Azure region for resources |
| `subnet_id` | string | Azure subnet ID for VM deployment |
| `ssh_public_key` | string | SSH public key for VM access |

### Optional Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `os_disk_size` | number | 100 | OS disk size in GB (30-4096) |
| `os_disk_storage_type` | string | Standard_LRS | OS disk storage type |
| `data_disk_sizes` | list(number) | [] | List of data disk sizes in GB |
| `data_disk_storage_type` | string | Standard_LRS | Data disk storage type |
| `nsg_id` | string | "" | Network Security Group ID |
| `assign_public_ip` | bool | false | Assign public IP address |
| `accelerated_networking` | bool | false | Enable accelerated networking |
| `admin_username` | string | azureuser | Admin username |
| `image_publisher` | string | Canonical | OS image publisher |
| `image_offer` | string | 0001-com-ubuntu-server-jammy | OS image offer |
| `image_sku` | string | 22_04-lts-gen2 | OS image SKU |
| `image_version` | string | latest | OS image version |
| `cloud_init_enabled` | bool | false | Enable cloud-init provisioning |
| `cloud_init_script` | string | "" | Cloud-init script content |
| `node_taints` | list(string) | [] | Kubernetes node taints |
| `node_labels` | map(string) | {} | Kubernetes node labels |
| `tags` | map(string) | {} | Azure resource tags |

## Outputs

| Output | Description |
|--------|-------------|
| `vm_id` | Azure resource ID of the VM |
| `vm_name` | Name of the VM |
| `private_ip_address` | Private IP address |
| `public_ip_address` | Public IP address (if assigned) |
| `network_interface_id` | NIC resource ID |
| `data_disk_ids` | List of data disk resource IDs |
| `kubernetes_node_info` | Node configuration (taints and labels) |

## Azure VM Size Recommendations

### Small Cluster (Development/Testing)
- **Control Plane**: Standard_D2s_v5 (2 vCPU, 8 GB)
- **System**: Standard_D2s_v5 (2 vCPU, 8 GB)
- **Generic Workers**: Standard_D4s_v5 (4 vCPU, 16 GB)
- **NFS/Jump**: Standard_B2s (2 vCPU, 4 GB)

### Medium Cluster (Production)
- **Control Plane**: Standard_D4s_v5 (4 vCPU, 16 GB)
- **System**: Standard_D8s_v5 (8 vCPU, 32 GB)
- **CAS Nodes**: Standard_E16s_v5 (16 vCPU, 128 GB) - Memory-optimized
- **Generic Workers**: Standard_D16s_v5 (16 vCPU, 64 GB)
- **NFS**: Standard_D4s_v5 (4 vCPU, 16 GB) with 4x1TB disks

### Large Cluster (Enterprise)
- **Control Plane**: Standard_D8s_v5 (8 vCPU, 32 GB) - HA with 3+ nodes
- **System**: Standard_D16s_v5 (16 vCPU, 64 GB)
- **CAS Nodes**: Standard_E20s_v5 (20 vCPU, 160 GB)
- **Generic Workers**: Standard_D24s_v5 (24 vCPU, 96 GB)

## Storage Disk Configuration Examples

### CAS Node (In-Memory Analytics)
```hcl
data_disk_sizes = [512, 512]  # 2x512GB for memory spill
```

### Stateful Services (Databases, Caches)
```hcl
data_disk_sizes = [512, 512]  # 2x512GB for data redundancy
```

### NFS Server (Shared Storage)
```hcl
data_disk_sizes = [1024, 1024, 1024, 1024]  # 4x1TB for RAID1
```

### Stateless Services
```hcl
data_disk_sizes = [256]  # 1x256GB for container cache
```

## Cloud-Init Examples

### Basic Package Update
```hcl
cloud_init_script = <<-EOT
  #!/bin/bash
  apt-get update
  apt-get install -y curl wget vim
EOT
```

### NFS Server Setup
```hcl
cloud_init_script = <<-EOT
  #!/bin/bash
  apt-get update
  apt-get install -y nfs-kernel-server
  mkdir -p /export/viya
  echo "/export/viya *(rw,sync,no_subtree_check)" >> /etc/exports
  exportfs -a
  systemctl restart nfs-kernel-server
EOT
```

### Kubernetes Node Preparation
```hcl
cloud_init_script = <<-EOT
  #!/bin/bash
  apt-get update
  apt-get install -y curl wget vim jq
  
  # Disable swap
  swapoff -a
  sed -i '/ swap / s/^/#/' /etc/fstab
  
  # Set kernel parameters
  echo "vm.overcommit_memory=1" >> /etc/sysctl.conf
  sysctl -p
EOT
```

## Kubernetes Integration

### Control Plane Taints
```hcl
node_taints = ["node-role.kubernetes.io/control-plane:NoSchedule"]
```

### CAS Node Taints
```hcl
node_taints = ["workload.sas.com/class=cas:NoSchedule"]
```

### CAS Node Labels
```hcl
node_labels = {
  "workload.sas.com/class" = "cas"
}
```

### System Node Label
```hcl
node_labels = {
  "kubernetes.azure.com/mode" = "system"
}
```

## Network Security

The module creates network interfaces but does not directly manage security rules. Association with a Network Security Group (NSG) is optional via the `nsg_id` variable.

Recommended NSG rules for Kubernetes:
- **SSH (22)**: To admin nodes
- **Kubernetes API (6443)**: For cluster communication
- **Kubelet (10250)**: For monitoring
- **Data replication (2379-2380)**: For etcd
- **Custom application ports**: As needed

Use the `azure_network` module to create and manage NSG rules.

## Troubleshooting

### VM Creation Fails Due to SSH Key
Ensure the SSH public key is:
- In valid OpenSSH format (RSA, ECDSA, or ED25519)
- Readable by the Terraform process
- Not encrypted with a passphrase

### Data Disk Not Appearing
1. Verify disk creation: `az vm disk list --resource-group <rg> --vm-name <vm>`
2. Connect to VM: `ssh azureuser@<ip>`
3. Initialize disk: `fdisk -l` to list attached disks
4. Format and mount: `mkfs.ext4 /dev/sdc` and `mount /dev/sdc /mnt/data`

### Network Interface Configuration
The module creates a dynamic private IP. To use a static IP, modify the NIC configuration:
```hcl
ip_configuration {
  ...
  private_ip_address_allocation = "Static"
  private_ip_address            = "10.0.1.10"
}
```

## License

Copyright © 2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0

# Valid Configuration Variables

Supported configuration variables are listed in the tables below.  All variables can also be specified on the command line.  Values specified on the command line will override values in configuration defaults files.

## Table of Contents

  - [Required Variables](#required-variables)
  - [Admin Access](#admin-access)
  - [Networking](#networking)
      - [Use Existing](#use-existing)
  - [General](#general)
  - [Node Pools](#nodepools)
    - [Default Node Pool](#default-nodepool)
    - [Additional Node Pools](#additional-nodepools)
  - [Storage](#storage)
  - [Postgres](#postgres)

## vSphere/vCenter

### Terraform `terraform.tfvars` file

Terraform input variables can be set in the following ways:
- Individually, with the [-var command line option](https://www.terraform.io/docs/configuration/variables.html#variables-on-the-command-line).
- In [variable definitions (.tfvars) files](https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files). We recommend this way for most variables.
- As [environment variables](https://www.terraform.io/docs/configuration/variables.html#environment-variables).

#### General Items

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| ansible_user | The user ID on your systems that Ansible uses to perform its tasks | string | | Must have password-less sudo privileges |
| ansible_password | The user account password on your systems that Ansible uses to perform its tasks | string | | |
| prefix | A prefix used in the names of all the resources created by this script | string | | |
| gateway | DNS gateway for vSphere/vCenter | string | | |
| netmask | Netmask for your network | number | 16 | The value must provide access from your machine's IP to the gateway provided |

#### vSphere

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| vsphere_server        | Name of the vSphere server | string | | |
| vsphere_cluster       | Name of the vSphere cluster | string | | |
| vsphere_datacenter    | Name of the vSphere data center | string | | |
| vsphere_datastore     | Name of the vSphere data store to use for the VMs | string | | |
| vsphere_resource_pool | Name of the vSphere resource pool to use for the VMs | string | | |
| vsphere_folder        | Name of the vSphere folder to store the VMs | string | | |
| vsphere_template      | Name of the VM template to clone to create VMs for the cluster | string | | |
| vsphere_network       | Name of the network to to use for the VMs | string | | |

#### Systems

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| system_ssh_keys_dir | Directory holding public keys to be used on each system | string | | |

#### Kubernetes Cluster

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
cluster_version        | Kubernetes version | string | | |
cluster_cni            | Kubernetes Container Network Interface (CNI) | string | | |
cluster_cri            | Kubernetes Container Runtime Interface (CRI) | string | | |
cluster_service_subnet | Kubernetes service subnet | string | | |
cluster_pod_subnet     | Kubernetes Pod subnet | string | | |
cluster_domain         | Cluster domain suffix for DNS | string | | |

#### Kubernetes Cluster VIP and Cloud Provider

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
kube_vip_version   | kube-vip version | string | "0.4.4" | |
kube_vip_interface | kube-vip interface | string | "ens160" | |
kube_vip_ip        | kube-vip IP address | string | | |
kube_vip_dns       | kube-vip DNS | string | | |
kube_vip_range     | kube-vip IP address range | string | | |

#### Control Plan Node Specs

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| control_plane_num_cpu | # of CPUs | number | 2 | |
| control_plane_ram | Size of RAM in MB | number | 4096 | |
| control_plane_disk_size | Size of disk in GB | number | 40 | |
| control_plane_ips | List of static IP addresses used in creating control_plane nodes | list(string) | | Cannot be used if `control_plane_count` is being used. |
| control_plane_count | Number of control plane nodes to create with DHCP IP address assignment | number | | Cannot be used if `control_plane_ips` is being used. |
| control_plane_ssh_key_name | Name for generated control plane SSH key | string | "cp_ssh" | |

Sample:

```bash
#   Suggested node specs shown below. Entries for 3
#   IPs to support HA control plane
#
control_plane_num_cpu   = 8     # 8 CPUs
control_plane_ram       = 16384 # 16 GB 
control_plane_disk_size = 100   # 100 GB
control_plane_ips = [           # Assigned values for static IP addresses - for HA you need 3/5/7/9/... IPs
  "",
  "",
  ""
]
control_plane_ssh_key_name = "" # Name for generated control plane SSH key
```

#### Node Specs

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| node_num_cpu | Number of CPUs | number | 2 | |
| node_ram | Size of RAM in MB | number | 4096 | |
| node_disk_size | Size of disk in GB | number | 40 | |
| node_ips | List of static IP addresses used in creating control_plane nodes | list(string) | | Cannot be used if `node_count` is being used. |
| node_count | Number of control plane nodes to create with DHCP IP address assignment | number | | Cannot be used if `node_ips` is being used. |

Sample:

```bash
#   Suggested node specs shown below. Entries for 6
#   IPs to support SAS Viya 4 deployment
#
node_num_cpu   = 16     # 16 CPUs
node_ram       = 131072 # 128 GB
node_disk_size = 250    # 250 GB
node_ips = [            # Assigned values for static IPs
  "",
  "",
  "",
  "",
  "",
  ""
]
```

#### Jump Server

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| create_jump | Creation flag | bool | false | |
| jump_num_cpu | # of CPUs | number | 4 | |
| jump_ram | Size of RAM in MB | number | 8092 | |
| jump_disk_size | Size of disk in GB | number | 100 | |
| jump_ip | Static IP address for jump server | string | | |

Sample:

```bash
# Jump server
create_jump    = true # Creation flag
jump_num_cpu   = 4    # 4 CPUs
jump_ram       = 8092 # 8 GB
jump_disk_size = 100  # 100 GB
jump_ip        = ""   # Assigned values for static IPs
```

#### NFS Server

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| create_nfs | Creation flag | bool | false | |
| nfs_num_cpu | # of CPUs | number | 4 | |
| nfs_ram | Size of RAM in MB | number | 8092 | |
| nfs_disk_size | Size of disk in GB | number | 250 | |
| nfs_ip | Static IP for jump server | string | | |

Sample:

```bash
# NFS server
create_nfs    = true  # Creation flag
nfs_num_cpu   = 8     # 8 CPUs
nfs_ram       = 16384 # 16 GB
nfs_disk_size = 500   # 500 GB
nfs_ip        = ""    # Assigned values for static IP addresses
```

#### PostgreSQL Server

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| server_num_cpu | # of CPUs | number | 8 | |
| server_ram | Size of RAM in MB | number | 16385 | |
| server_disk_size | Size of disk in GB | number | 250 | |
| server_ip | Static IP address for PostgreSQL server | string | | This is a required field |
| server_version | PostgreSQL version | number | 12 | |
| server_ssl | Enable/disable SSL | string | "off" | |
| administrator_login | Admin user | string | "postgres" | |
| administrator_password | Admin password | string | "my$up3rS3cretPassw0rd" | |

Sample:

```bash
# Postgres Servers
postgres_servers = {
  default = {
    server_num_cpu         = 8                       # 8 CPUs
    server_ram             = 16384                   # 16 GB
    server_disk_size       = 250                     # 256 GB
    server_ip              = ""                      # Assigned values for static IP addresses - REQUIRED
    server_version         = 12                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
  }
}
```

## Bare Metal

### Ansible `ansible-vars.yaml` file

## General

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| kubernetes_version | Cluster Kubernetes version | string | "1.22.9" | Valid values are listed here: [Kubernetes Releases](https://kubernetes.io/releases/) |
| create_static_kubeconfig | Allows the user to create a provider or service account based kubeconfig file | bool | false | A value of `false` defaults to using the cloud provider's mechanism for generating the kubeconfig file. A value of `true` creates a static kubeconfig file, which uses a service account and cluster role binding to provide credentials. |
| jump_vm_admin | OS Admin User for the Jump Server | string | "jumpuser" | | |
| jump_rwx_filestore_path | File store mount point on Jump Server | string | "/viya-share" | |
| tags | Map of common tags to be placed on all resources created by this script | map | {} | |

## Node Pools

### Default Node Pool

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| default_nodepool_taints | Taints for the default node pool VMs | list of strings | [] | |
| default_nodepool_labels | Labels to add to the default node pool VMs | map | {} | |

### Additional Node Pools

Additional node pools can be created separate from the default node pool. This is done with the `node_pools` variable, which is a map of objects. Each node pool requires the following variables:

| Name | Description | Type | Notes |
| :--- | ---: | ---: | ---: |
| node_taints | Taints for the node pool VMs | list of strings | |
| node_labels | Labels to add to the node pool VMs | map | |

The default values for the `node_pools` variable are:

```yaml
# CAS - Recommended 3 nodes
cas = {
  "node_taints"  = ["workload.sas.com/class=cas:NoSchedule"]
  "node_labels" = {
    "workload.sas.com/class" = "cas"
  }
},
# Compute - Recommended 3 nodes
compute = {
  "node_taints"  = ["workload.sas.com/class=compute:NoSchedule"]
  "node_labels" = {
    "workload.sas.com/class"        = "compute"
    "launcher.sas.com/prepullImage" = "sas-programming-environment"
  }
},
# Connect - Recommended 3 nodes
connect = {
  "node_taints"  = ["workload.sas.com/class=connect:NoSchedule"]
  "node_labels" = {
    "workload.sas.com/class"        = "connect"
    "launcher.sas.com/prepullImage" = "sas-programming-environment"
  }
},
# Stateless - Recommended 3 nodes
stateless = {
  "node_taints"  = ["workload.sas.com/class=stateless:NoSchedule"]
  "node_labels" = {
    "workload.sas.com/class" = "stateless"
  }
},
# Stateful - Recommended 3 nodes
stateful = {
  "node_taints"  = ["workload.sas.com/class=stateful:NoSchedule"]
  "node_labels" = {
    "workload.sas.com/class" = "stateful"
  }
}
```

## Storage

[TODO - Need to determine NFS Server and or Alternative]

## PostgreSQL Servers

When setting up ***external database servers***, you must provide information about those servers in the `postgres_servers` variable block. Each entry in the variable block represents a ***single database server***.

This code only configures database servers. No databases are created during the infrastructure setup.

The variable has the following format:

```terraform
postgres_servers = {
  default = {},
  ...
}
```

**NOTE**: The `default = {}` element is always required when creating external databases. This is the system's default database server.

Each server element, like `foo = {}`, can contain none, some, or all of the parameters listed below:

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| administrator_login | The administrator login for the PostgreSQL server. Changing this forces a new resource to be created. | string | "pgadmin" | | |
| administrator_password | The password associated with the administrator_login for the PostgreSQL server | string | "my$up3rS3cretPassw0rd" |  |
| server_version | The version of the  PostgreSQL server instance | string | "11" | Supported values are 11 and 12 |
| ssl_enforcement_enabled | Enforce SSL on connections to the PostgreSQL database | bool | true | |

Here is an example of the `postgres_servers` variable with the `default` entry only overriding the `administrator_password` parameter and the `cps` entry overriding all of the parameters:

```terraform
postgres_servers = {
  default = {
    administrator_password       = "D0ntL00kTh1sWay"
  },
  another-server = {
    machine_type                           = "db-custom-8-30720"
    storage_gb                             = 10
    backups_enabled                        = true
    backups_start_time                     = "21:00"
    backups_location                       = null
    backups_point_in_time_recovery_enabled = false
    backup_count                           = 7 # Number of backups to retain, not in days
    administrator_login                    = "pgadmin"
    administrator_password                 = "my$up3rS3cretPassw0rd"
    server_version                         = "11"
    availability_type                      = "ZONAL"
    ssl_enforcement_enabled                = true
    database_flags                         = [{ name = "foo" value = "true"}, { name = "bar", value = "false"}]
  }
}
```

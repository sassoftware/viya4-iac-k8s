# Valid Configuration Variables

Supported configuration variables are listed in the tables below.  All variables can also be specified on the command line.  Values specified on the command line will override values in configuration defaults files.

## Table of Contents

- [Valid Configuration Variables](#valid-configuration-variables)
  - [Table of Contents](#table-of-contents)
  - [vSphere/vCenter](#vspherevcenter)
    - [Terraform `terraform.tfvars` file](#terraform-terraformtfvars-file)
      - [General Items](#general-items)
      - [vSphere](#vsphere)
      - [Systems](#systems)
      - [Kubernetes Cluster](#kubernetes-cluster)
      - [Kubernetes Cluster VIP and Cloud Provider](#kubernetes-cluster-vip-and-cloud-provider)
      - [Control Plane](#control-plane)
      - [Node Pools](#node-pools)
      - [Jump Server](#jump-server)
      - [NFS Server](#nfs-server)
      - [PostgreSQL Server](#postgresql-server)
  - [Bare Metal](#bare-metal)
    - [Ansible `ansible-vars.yaml` file](#ansible-ansible-varsyaml-file)
    - [Labels/Taints](#labelstaints)
      - [Labels](#labels)
      - [Taints](#taints)
    - [Ansible `inventory` file](#ansible-inventory-file)
  - [Storage](#storage)
  - [PostgreSQL Servers](#postgresql-servers)

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
| system_ssh_keys_dir | Directory holding public keys to be used on each system | string | | These keys are applied to the OS and root users of your machines |

#### Kubernetes Cluster

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
cluster_version        | Kubernetes version | string | "1.22.10" | Valid values are listed here: [Kubernetes Releases](https://kubernetes.io/releases/) |
cluster_cni            | Kubernetes Container Network Interface (CNI) | string | "calico" | |
cluster_cri            | Kubernetes Container Runtime Interface (CRI) | string | "containerd" | |
cluster_service_subnet | Kubernetes service subnet | string | "10.43.0.0/16" | |
cluster_pod_subnet     | Kubernetes Pod subnet | string | "10.42.0.0/16" | |
cluster_domain         | Cluster domain suffix for DNS | string | | |

#### Kubernetes Cluster VIP and Cloud Provider

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
kube_vip_version   | kube-vip version | string | "0.4.4" | The minimal supported version is 0.4.4 |
kube_vip_ip        | kube-vip IP address | string | | |
kube_vip_dns       | kube-vip DNS | string | | |
kube_vip_range     | kube-vip IP address range | string | | |

#### Control Plane

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| control_plane_ssh_key_name | Name for generated control plane SSH key | string | "cp_ssh" | |

#### Node Pools

Node pools are a map of objects. They represent information about each pool type, its physical hardware, along with their labels and taints. Each node pool requires the following variables:

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| count | Number of nodes | number | | Setting this variable creates nodes with dynamic IPs assigned from your network. Cannot be used with the `ip_addresses` field|
| cpus | Number of CPUS cores | number | | |
| memory | Memory in MB | number | | |
| disk | Size of disk in GB | number| | |
| ip_addresses | List of static IP addresses used in creating control_plane nodes | list(string) |  | Setting this variable creates nodes with static ips assigned from this list. Cannot be used if the `count` field is being used |
| node_taints |  | list(string) | | |
| node_labels |  | map(string) | | |

There is no default type for the node pools but examples based on what SAS recommends are listed in the example files. Below is a sample of a basic cluster `node_pools` definition one would use in their `terraform.tfvars` file.

**NOTE**: These node pools are required for the `node_pools`:

- control_plane
- system

Sample `node_pool` entry:

```yaml
# Cluster Node Pools config
#
#   Your node pools must contain at least 3 or more nodes.
#   The required node types are:
#
#   * control_plane - Having an odd number 3/5/7... ensures
#                     HA while using kube-vip
#   * system        - System node pool to run misc pods, etc
#   * cas           - CAS Nodes
#   * <node type>   - Any number of node types with unique names.
#                     These are typically: compute, stateful, and
#                     stateless. 
#
node_pools = {
  #
  # REQUIRED NODE TYPE - DO NOT REMOVE and DO NOT CHANGE THE NAME
  #                      Other variables may be altered
  control_plane = {
    cpus        = 2
    memory      = 4096
    disk        = 100
    ip_addresses = [
      "192.168.7.21",
      "192.168.7.22",
      "192.168.7.23",
    ]
    node_taints = []
    node_labels = {}
  },
  #
  # REQUIRED NODE TYPE - DO NOT REMOVE and DO NOT CHANGE THE NAME
  #                      Other variables may be altered
  system = {
    count       = 1
    cpus        = 8
    memory      = 16384
    disk        = 100
    node_taints = []
    node_labels = {
      "kubernetes.azure.com/mode" = "system" # REQUIRED LABEL - DO NOT REMOVE
    }
  },
  cas = {
    count       = 3
    cpus        = 16
    memory      = 131072
    disk        = 350
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },
  compute = {
    count       = 1
    cpus        = 16
    memory      = 131072
    disk        = 100
    node_taints = ["workload.sas.com/class=compute:NoSchedule"]
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  },
  stateful = {
    count       = 1
    cpus        = 8
    memory      = 32768
    disk        = 100
    node_taints = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateful"
    }
  },
  stateless = {
    count       = 2
    cpus        = 8
    memory      = 32768
    disk        = 100
    node_taints = ["workload.sas.com/class=stateless:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateless"
    }
  }
}
```

#### Jump Server

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| create_jump | Creation flag | bool | false | |
| jump_num_cpu | # of CPUs | number | 4 | |
| jump_memory | Memory in MB | number | 8092 | |
| jump_disk_size | Size of disk in GB | number | 100 | |
| jump_ip | Static IP address for jump server | string | | |

Sample:

```bash
# Jump server
create_jump    = true # Creation flag
jump_num_cpu   = 4    # 4 CPUs
jump_memory    = 8092 # 8 GB
jump_disk_size = 100  # 100 GB
jump_ip        = ""   # Assigned values for static IPs
```

#### NFS Server

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| create_nfs | Creation flag | bool | false | |
| nfs_num_cpu | # of CPUs | number | 4 | |
| nfs_memory | Memory in MB | number | 8092 | |
| nfs_disk_size | Size of disk in GB | number | 250 | |
| nfs_ip | Static IP for jump server | string | | |

Sample:

```bash
# NFS server
create_nfs    = true  # Creation flag
nfs_num_cpu   = 8     # 8 CPUs
nfs_memory    = 16384 # 16 GB
nfs_disk_size = 500   # 500 GB
nfs_ip        = ""    # Assigned values for static IP addresses
```

#### PostgreSQL Server

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| server_num_cpu | # of CPUs | number | 8 | |
| server_memory | Memory in MB | number | 16385 | |
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
    server_memory          = 16384                   # 16 GB
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

Variables used to describe your machines.

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| ansible_user | The user ID on your systems that Ansible uses to perform its tasks | string | | Must have password-less sudo privileges |
| ansible_password | The user account password on your systems that Ansible uses to perform its tasks | string | | |
| vm_os | Operating system used on your machines | string | "ubuntu" | All machines in your setup must have the same operating system |
| vm_arch | Machine architecture | string | "amd64" | |
| enable_cgroup_v2 | Enable cgroup_v2 on your machines | bool | true | |
| system_ssh_keys_dir | Directory holding public keys to be used on each system | string | "~/.ssh" | |
| prefix | A prefix used in the names of all the resources created by this script | string | | |
| deployment_type | | string | | |
| kubernetes_cluster_name | Cluster name | string | "{{ prefix }}-oss" | This item is auto-filled **ONLY** change the prefix value above |
| kubernetes_version | Kubernetes version | string | "1.22.10" | Valid values are listed here: [Kubernetes Releases](https://kubernetes.io/releases/) |
| kubernetes_upgrade_allowed | | bool | true | |
| kubernetes_arch | | string | "{{ vm_arch }}" | |
| kubernetes_cni | Kubernetes Container Network Interface (CNI) | string | "calico" | |
| kubernetes_cri | Kubernetes Container Runtime Interface (CRI) | string | "containerd" | |
| kubernetes_service_subnet | Kubernetes service subnet | string | "10.43.0.0/16" | |
| kubernetes_pod_subnet | Kubernetes Pod subnet | string | "10.42.0.0/16" | |
| kubernetes_vip_version | kube-vip version | string | "0.4.4" | |
| kubernetes_vip_interface | kube-vip interface | string | | |
| kubernetes_vip_ip | kube-vip IP address | string | | |
| kubernetes_vip_loadbalanced_dns | kube-vip DNS | string | | |
| kubernetes_vip_cloud_provider_range | kube-vip IP address range | string | | |
| node_labels | Labels applied to nodes in your cluster | map(list(string)) | | |
| node_taints | Taints applied to nodes in your cluster | map(list(string)) | | |
| control_plane_ssh_key_name | Name for generated control plane SSH key | string | "cp_ssh" | |
| jump_ip | Dynamic or static IP address that is assigned to your Jump Box | string | | |
| nfs_ip | Dynamic or static IP address that is assigned to your NFS server | string | | |

### Labels/Taints

Labels and taints are applied to each node that matches the label or taint key name. The following examples outline these names and the labels/taints associated with those nodes.

#### Labels

To label your machines as specific nodes add the following items to your `ansible-vars.yaml` file:

```yaml
node_labels:
  cas:
    - workload.sas.com/class=cas
  compute:
    - launcher.sas.com/prepullImage=sas-programming-environment
    - workload.sas.com/class=compute
  stateful:
    - workload.sas.com/class=stateful
  stateless:
    - workload.sas.com/class=stateless
  system:
    - kubernetes.azure.com/mode=system
```

**NOTE**: The label on the `system` node pool is required if you DO NOT want SAS Software running on your system node(s).

#### Taints

To taint your machines as specific nodes add the following items to your `ansible-vars.yaml` file:

```yaml
node_taints:
  cas:
    - workload.sas.com/class=cas:NoSchedule
  compute:
    - workload.sas.com/class=compute:NoSchedule
  stateful:
    - workload.sas.com/class=stateful:NoSchedule
  stateless:
    - workload.sas.com/class=stateless:NoSchedule
```

### Ansible `inventory` file

This inventory file represents the machines you will be using in your kubernetes deployment for SAS Viya. An example and information on this file can be found [here](../examples/bare-metal/sample-inventory).

## Storage

An NFS server is setup by default. This is a required machine as it's used as backing storage for the `default` storage class created. Information on setting up that machine is listed [here](#NFSServer)

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

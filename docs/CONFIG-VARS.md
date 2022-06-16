# Valid Configuration Variables

Supported configuration variables are listed in the tables below.  All variables can also be specified on the command line.  Values specified on the command line will override values in configuration defaults files.

<!-- vscode-markdown-toc -->
* 1. [Table of Contents](#TableofContents)
* 2. [vSphere/vCenter](#vSpherevCenter)
	* 2.1. [Terraform `terraform.tfvars` file](#Terraformterraform.tfvarsfile)
		* 2.1.1. [General Items](#GeneralItems)
		* 2.1.2. [vSphere](#vSphere)
		* 2.1.3. [Systems](#Systems)
		* 2.1.4. [Kubernetes Cluster](#KubernetesCluster)
		* 2.1.5. [Kubernetes Cluster VIP and Cloud Provider](#KubernetesClusterVIPandCloudProvider)
		* 2.1.6. [Control Plane](#ControlPlane)
		* 2.1.7. [Node Pools](#NodePools)
		* 2.1.8. [Jump Server](#JumpServer)
		* 2.1.9. [NFS Server](#NFSServer)
		* 2.1.10. [PostgreSQL Server](#PostgreSQLServer)
* 3. [Bare Metal](#BareMetal)
	* 3.1. [Ansible `ansible-vars.yaml` file](#Ansibleansible-vars.yamlfile)
* 4. [General](#General)
* 5. [Node Pools](#NodePools-1)
	* 5.1. [Labels](#Labels)
	* 5.2. [Taints](#Taints)
* 6. [Storage](#Storage)
* 7. [PostgreSQL Servers](#PostgreSQLServers)

<!-- vscode-markdown-toc-config
	numbering=true
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->

##  1. <a name='TableofContents'></a>Table of Contents

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

##  2. <a name='vSpherevCenter'></a>vSphere/vCenter

###  2.1. <a name='Terraformterraform.tfvarsfile'></a>Terraform `terraform.tfvars` file

Terraform input variables can be set in the following ways:
- Individually, with the [-var command line option](https://www.terraform.io/docs/configuration/variables.html#variables-on-the-command-line).
- In [variable definitions (.tfvars) files](https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files). We recommend this way for most variables.
- As [environment variables](https://www.terraform.io/docs/configuration/variables.html#environment-variables).

####  2.1.1. <a name='GeneralItems'></a>General Items

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| ansible_user | The user ID on your systems that Ansible uses to perform its tasks | string | | Must have password-less sudo privileges |
| ansible_password | The user account password on your systems that Ansible uses to perform its tasks | string | | |
| prefix | A prefix used in the names of all the resources created by this script | string | | |
| gateway | DNS gateway for vSphere/vCenter | string | | |
| netmask | Netmask for your network | number | 16 | The value must provide access from your machine's IP to the gateway provided |

####  2.1.2. <a name='vSphere'></a>vSphere

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

####  2.1.3. <a name='Systems'></a>Systems

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| system_ssh_keys_dir | Directory holding public keys to be used on each system | string | | These keys are applied to the OS and root users of your machines |

####  2.1.4. <a name='KubernetesCluster'></a>Kubernetes Cluster

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
cluster_version        | Kubernetes version | string | | |
cluster_cni            | Kubernetes Container Network Interface (CNI) | string | "calico" | |
cluster_cri            | Kubernetes Container Runtime Interface (CRI) | string | "containerd" | |
cluster_service_subnet | Kubernetes service subnet | string | "10.43.0.0/16" | |
cluster_pod_subnet     | Kubernetes Pod subnet | string | "10.42.0.0/16" | |
cluster_domain         | Cluster domain suffix for DNS | string | | |

####  2.1.5. <a name='KubernetesClusterVIPandCloudProvider'></a>Kubernetes Cluster VIP and Cloud Provider

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
kube_vip_version   | kube-vip version | string | "0.4.4" | |
kube_vip_interface | kube-vip interface | string | | |
kube_vip_ip        | kube-vip IP address | string | | |
kube_vip_dns       | kube-vip DNS | string | | |
kube_vip_range     | kube-vip IP address range | string | | |

####  2.1.6. <a name='ControlPlane'></a>Control Plane

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| control_plane_ssh_key_name | Name for generated control plane SSH key | string | "cp_ssh" | |

####  2.1.7. <a name='NodePools'></a>Node Pools

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

* control_plane
* system

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

####  2.1.8. <a name='JumpServer'></a>Jump Server

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

####  2.1.9. <a name='NFSServer'></a>NFS Server

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

####  2.1.10. <a name='PostgreSQLServer'></a>PostgreSQL Server

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

##  3. <a name='BareMetal'></a>Bare Metal

###  3.1. <a name='Ansibleansible-vars.yamlfile'></a>Ansible `ansible-vars.yaml` file

##  4. <a name='General'></a>General

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| kubernetes_version | Cluster Kubernetes version | string | "1.22.10" | Valid values are listed here: [Kubernetes Releases](https://kubernetes.io/releases/) |
| create_static_kubeconfig | Allows the user to create a provider or service account based kubeconfig file | bool | false | A value of `false` defaults to using the cloud provider's mechanism for generating the kubeconfig file. A value of `true` creates a static kubeconfig file, which uses a service account and cluster role binding to provide credentials. |
| jump_vm_admin | OS Admin User for the Jump Server | string | "jumpuser" | | |
| jump_rwx_filestore_path | File store mount point on Jump Server | string | "/viya-share" | |
| tags | Map of common tags to be placed on all resources created by this script | map | {} | |

##  5. <a name='NodePools-1'></a>Node Pools

A grouping of machines with host names having a matching patterns, i.e. cas, stateful, stateless, etc. constitute a node pool in this context.

This is a requirement for the tooling to add the appropriate labels and taints for each node. If you choose NOT to follow this naming convention you will need to add these labels and taints yourself to each node in the cluster. If you choose not to apply any labels or taints to nodes in your cluster, the SAS Viya software will run as expected; however, the performance may suffer.

Please refer to the SAS docs here for more information about labels and taints.

###  5.1. <a name='Labels'></a>Labels

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

###  5.2. <a name='Taints'></a>Taints

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

##  6. <a name='Storage'></a>Storage

An NFS server is setup by default. This is a required machine as it's used as backing storage for the `default` storage class created. Information on setting up that machine is listed [here](#NFSServer)

##  7. <a name='PostgreSQLServers'></a>PostgreSQL Servers

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

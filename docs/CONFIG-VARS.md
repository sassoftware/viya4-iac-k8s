# Valid Configuration Variables

Supported configuration variables are listed in the tables below.  All variables can also be specified on the command line.  Values specified on the command line will override values in configuration defaults files.

## Table of Contents

- [Valid Configuration Variables](#valid-configuration-variables)
  - [Table of Contents](#table-of-contents)
  - [VMware vSphere/vCenter](#vmware-vspherevcenter)
    - [Terraform terraform.tfvars file](#terraform-terraformtfvars-file)
      - [General Items](#general-items)
      - [vSphere](#vsphere)
      - [Systems](#systems)
      - [Kubernetes Cluster](#kubernetes-cluster)
      - [Kubernetes Cluster Virtual IP Address](#kubernetes-cluster-virtual-ip-address)
      - [Kubernetes Load Balancer](#kubernetes-load-balancer)
      - [Control Plane](#control-plane)
      - [Node Pools](#node-pools)
      - [Jump Server](#jump-server)
      - [NFS Server](#nfs-server)
      - [PostgreSQL Server](#postgresql-server)
  - [Bare Metal](#bare-metal)
    - [Ansible ansible-vars.yaml File](#ansible-ansible-varsyaml-file)
    - [Labels/Taints](#labelstaints)
      - [Labels](#labels)
      - [Taints](#taints)
    - [Ansible inventory file](#ansible-inventory-file)
  - [Storage](#storage)
  - [PostgreSQL Servers](#postgresql-servers)

## VMware vSphere/vCenter

### Terraform terraform.tfvars file

Terraform input variables can be set in the following ways:

- Individually, with the [-var command line option](https://www.terraform.io/docs/configuration/variables.html#variables-on-the-command-line).
- In [variable definitions (.tfvars) files](https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files). We recommend using this method for most variables.
- As [environment variables](https://www.terraform.io/docs/configuration/variables.html#environment-variables).

#### General Items

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| ansible_user | The user ID on your systems that Ansible uses to perform its tasks | string | | Requires password-less sudo privileges. |
| ansible_password | The password for the user account on your systems that Ansible uses to perform its tasks | string | | |
| prefix | A prefix used in the names of all the resources created by this script | string | | |
| gateway | DNS gateway for vSphere/vCenter | string | | |
| netmask | Subnet mask for your network | number | 16 | The value must provide access from your machine's IP address to the gateway. |

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
| system_ssh_keys_dir | Directory holding public keys to be used on each system | string | "~/.ssh" | These keys are applied to the operating system and root users of your machines. |

#### Kubernetes Cluster

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| cluster_version        | Kubernetes version | string | "1.23.8" | Valid values are listed here: [SAS Viya platform Supported Kubernetes Versions](https://go.documentation.sas.com/doc/en/itopscdc/default/itopssr/n1ika6zxghgsoqn1mq4bck9dx695.htm#p03v0o4maa8oidn1awe0w4xlxcf6). |
| cluster_cni            | Kubernetes container network interface (CNI) | string | "calico" | |
| cluster_cni_version    | Kubernetes Container Network Interface (CNI) Version | string | "3.24.5" | |
| cluster_cri            | Kubernetes container runtime interface (CRI) | string | "containerd" | |
| cluster_service_subnet | Kubernetes service subnet | string | "10.43.0.0/16" | |
| cluster_pod_subnet     | Kubernetes pod subnet | string | "10.42.0.0/16" | |
| cluster_domain         | Cluster domain suffix for DNS | string | | |

#### Kubernetes Cluster Virtual IP Address

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| cluster_vip_version   | kube-vip version | string | "0.5.7" | Currently kube-vip is the only supported Kubernetes virtual IP address. The minimum supported version is 0.5.7. |
| cluster_vip_ip    | kube-vip IP address | string | | IP address assigned to the FQDN value. You must access the cluster via the FQDN value supplied. |
| cluster_vip_fqdn   | kube-vip DNS | string | | FQDN used in the creation of the kubeconfig file, which is used to access the cluster. |

#### Kubernetes Load Balancer

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| cluster_lb_type | Load balancer used in the cluster | string | "kube_vip" | Valid values: `kube_vip`, `metallb` |
| cluster_lb_addresses | IP addresses used by the load balancer | list | null | Values change depending on the load balancer that is selected. [This link](https://kube-vip.io/docs/usage/cloud-provider/#the-kube-vip-cloud-provider-configmap) provides more information about kube-vip load balancer addresses. [This link](https://metallb.universe.tf/configuration/#layer-2-configuration) provides more information about MetalLB load balancer addresses. |

#### Control Plane

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| control_plane_ssh_key_name | Name for SSH key generated for the control plane  | string | "cp_ssh" | |

#### Node Pools

Node pools are maps of objects. They represent information about each pool type, its physical hardware, and their labels and taints. Each node pool requires the following variables:

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| count | Number of nodes | number | | Setting this variable creates nodes with dynamic IP addresses that are assigned from your network. It cannot be used with the `ip_addresses` field. |
| cpus | Number of CPU cores | number | | |
| memory | Memory in MB | number | | |
| os_disk | Size of operating system disk in GB | number | | Operating system root disk. |
| misc_disk | Size of extra disks in GB | number | | Miscellaneous disks that are used for the local-storage storage class. At this time, these disk are empty partitions created and attached to your VM once created. These disks are used for the `local-storage` storage class created for those applications that need local vs networked storage to run proficiently. Requirements and information on this can be found [here](./REQUIREMENTS.md#storage) |
| ip_addresses | List of static IP addresses to be used in creating control_plane nodes | list(string) |  | Setting this variable creates nodes with static IP addresses assigned from this list. It cannot be used if the `count` field is used. |
| node_taints |  | list(string) | | |
| node_labels |  | map(string) | | |

There is no default type for SAS Viya platform node pools. However, examples that are based on SAS recommendations are listed in the example files. Below is a sample of a basic cluster `node_pools` definition that you could use in your terraform.tfvars file.

**NOTE**: These node pools are required for the `node_pools` variable:

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
    os_disk     = 100
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
    os_disk     = 100
    node_taints = []
    node_labels = {
      "kubernetes.azure.com/mode" = "system" # REQUIRED LABEL - DO NOT REMOVE
    }
  },
  cas = {
    count       = 3
    cpus        = 16
    memory      = 131072
    os_disk     = 350
    misc_disks = [
      150,
      150,
    ]    
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },
  compute = {
    count       = 1
    cpus        = 16
    memory      = 131072
    os_disk     = 100
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
    os_disk     = 100
    node_taints = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateful"
    }
  },
  stateless = {
    count       = 2
    cpus        = 8
    memory      = 32768
    os_disk     = 100
    node_taints = ["workload.sas.com/class=stateless:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateless"
    }
  },
  singlestore = {
    cpus    = 16
    memory  = 131072
    os_disk = 100
    misc_disks = [
      250,
      250,
      500,
      500,
    ]
    count       = 3
    node_taints = ["workload.sas.com/class=singlestore:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "singlestore"
    }
  },
}
```

#### Jump Server

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| create_jump | Creation flag | bool | false | |
| jump_num_cpu | # of CPU cores | number | 4 | |
| jump_memory | Memory in MB | number | 8092 | |
| jump_disk_size | Size of disk in GB | number | 100 | |
| jump_ip | Static IP address for jump server | string | | |

Sample:

```bash
# Jump server
create_jump    = true # Creation flag
jump_num_cpu   = 4    # 4 CPU cores
jump_memory    = 8092 # 8 GB
jump_disk_size = 100  # 100 GB
jump_ip        = ""   # Assigned values for static IP addresses
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
| server_ip | Static IP address for PostgreSQL server | string | | This is a required field. |
| server_version | PostgreSQL version | number | 12 | |
| server_ssl | Enable/disable SSL | string | "off" | |
| server_ssl_cert_file | Path to the PostgreSQL SSL certificate file | string | "" | If `server_ssl` is enabled and this variable is not defined, the system default SSL certificate is used. |
| server_ssl_key_file | Path to the PostgreSQL SSL key file | string | "" | If `server_ssl` is enabled and this variable is not defined, the system default SSL key is used. |
| administrator_login | Admin user | string | "postgres" | |
| administrator_password | Admin password | string | "my$up3rS3cretPassw0rd" | |

**NOTES**:

1. If you enable `server_ssl` without defining either `server_ssl_cert_file` or `server_ssl_cert_file`, the system's default SSL certificate and key are used instead. By default, on Ubuntu systems we create a copy of those files and name them `ssl-cert-sas-${PG_HOST}.pem` and `ssl-cert-sas-${PG_HOST}.key`.
    - The Ansible tasks that are performed include copying the certificate and key from the PostgreSQL VM into your local workspace directory.
2. If you are planning to use the [viya4-deployment repository](https://github.com/sassoftware/viya4-deployment) to perform a SAS Viya platform deployment where you have [full-stack TLS](https://github.com/sassoftware/viya4-deployment/blob/main/docs/CONFIG-VARS.md#tls) configured, make sure that the `V4_CFG_TLS_TRUSTED_CA_CERTS` variable in the viya4-deployment ansible-vars.yaml file points to a directory that contains the server_ssl_cert_file.

Sample:

```bash
# Postgres Servers
postgres_servers = {
  default = {
    server_num_cpu         = 8                       # 8 CPUs
    server_memory          = 16384                   # 16 GB
    server_disk_size       = 250                     # 256 GB
    server_ip              = ""                      # Assigned values for static IP addresses - REQUIRED
    server_version         = 13                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
  }
}
```

## Bare Metal

### Ansible ansible-vars.yaml File

The following variables are used to describe the machine targets for the SAS Viya platform deployment.

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| ansible_user | The user ID on your systems that Ansible uses to perform its tasks | string | | Requires password-less sudo privileges. |
| ansible_password | The password for the user account on your systems that Ansible uses to perform its tasks | string | | |
| vm_os | Operating system that is running on your machines | string | "ubuntu" | All machines in your cluster must have the same operating system. |
| vm_arch | Machine architecture | string | "amd64" | |
| enable_cgroup_v2 | Enable cgroup_v2 on your machines | bool | true | |
| system_ssh_keys_dir | Directory location of public keys to be used on each system | string | "~/.ssh" | |
| prefix | A prefix used in the names of all the resources created by this script | string | | |
| deployment_type | Type of deployment to be performed | string | "bare_metal" | Specify `bare_metal` or `vsphere`. |
| kubernetes_cluster_name | Cluster name | string | "{{ prefix }}-oss" | This item is auto-filled. **ONLY** change the `prefix` value described previously. |
| kubernetes_version | Kubernetes version | string | "1.23.8" | Valid values are listed here: [Kubernetes Releases](https://kubernetes.io/releases/). |
| kubernetes_upgrade_allowed | | bool | true | **NOTE:** Not currently used. |
| kubernetes_arch | | string | "{{ vm_arch }}" | This item is auto-filled. **ONLY** change the `vm_arch` value described previously. |
| kubernetes_cni | Kubernetes Container Network Interface (CNI) | string | "calico" | |
| kubernetes_cni_version | Kubernetes Container Network Interface (CNI) Version | string | "3.24.5" | |
| kubernetes_cri | Kubernetes Container Runtime Interface (CRI) | string | "containerd" | |
| kubernetes_service_subnet | Kubernetes service subnet | string | "10.43.0.0/16" | |
| kubernetes_pod_subnet | Kubernetes pod subnet | string | "10.42.0.0/16" | |
| kubernetes_vip_version | kube-vip version | string | "0.5.7" | |
| kubernetes_vip_ip | kube-vip IP address | string | | |
| kubernetes_vip_fqdn | kube-vip DNS | string | | |
| kubernetes_loadbalancer | Load balancer provider | string | "kube_vip" | Choices are `kube_vip` or `metallb`.
| kubernetes_loadbalancer_addresses | Load balancer IP addresses | string | [] | Values depend on the load balancer that is selected. [This link](https://kube-vip.io/docs/usage/cloud-provider/#the-kube-vip-cloud-provider-configmap) provides more information about kube-vip load balancer addresses. [This link](https://metallb.universe.tf/configuration/#layer-2-configuration) provides more information about MetalLB load balancer addresses. |
| node_labels | Labels applied to nodes in your cluster | map(list(string)) | | See [Labels/Taints](#labelstaints) below for more information. |
| node_taints | Taints applied to nodes in your cluster | map(list(string)) | | See [Labels/Taints](#labelstaints) below for more information. |
| control_plane_ssh_key_name | Name for generated control plane SSH key | string | "cp_ssh" | |
| jump_ip | Dynamic or static IP address that is assigned to your jump server | string | | |
| nfs_ip | Dynamic or static IP address that is assigned to your NFS server | string | | |

**NOTE**: For bare metal systems in order to leverage the `local-storage` storage class created by these scripts you need to have empty partitions attached to your machines. These disks are used for the `local-storage` storage class created for those applications that need local vs networked storage to run proficiently. If they are not present this storage class cannot be used. Be sure to alter your manifest files to take advantage of this new storage class where its needed.

### Labels/Taints

Labels and taints are applied to each node that matches the label or taint key name. The following examples outline these names and the labels/taints associated with those nodes.

#### Labels

To label your machines as specific nodes, add the following items to your ansible-vars.yaml file:

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
  singlestore:
    - workload.sas.com/class=singlestore
  system:
    - kubernetes.azure.com/mode=system
```

**NOTE**: The label on the system node pool is required if you DO NOT want SAS software to run on your system node(s).

#### Taints

To taint your machines as specific nodes, add the following items to your ansible-vars.yaml file:

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
  singlestore:
    - workload.sas.com/class=singlestore:NoSchedule
```

### Ansible inventory file

The inventory file represents the machines that you will be using in your Kubernetes deployment of the SAS Viya platform. An example and information about this file can be found [here](../examples/bare-metal/sample-inventory).

## Storage

An NFS server is set up by default. This is a required machine that is used as backing storage for the `default` storage class that is created. Information on setting up that machine is provided [here](#nfs-server).

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
| administrator_login | The administrator login account for the PostgreSQL server. Changing this forces a new resource to be created. | string | "pgadmin" | | |
| administrator_password | The password associated with the administrator_login for the PostgreSQL server | string | "my$up3rS3cretPassw0rd" |  |
| server_version | The version of the PostgreSQL server | string | "13" | Refer to the [SAS Viya platform System Requirements](https://go.documentation.sas.com/doc/en/sasadmincdc/default/itopssr/p05lfgkwib3zxbn1t6nyihexp12n.htm?fromDefault=#p1wq8ouke3c6ixn1la636df9oa1u) for the supported versions of PostgreSQL for the SAS Viya platform. |
| ssl_enforcement_enabled | Enforce SSL on connections to the PostgreSQL database | bool | true | |

Here is an example of the `postgres_servers` variable where the `default` entry only overrides the `administrator_password` parameter, and the `another-server` entry overrides all parameters:

```terraform
postgres_servers = {
  default = {
    administrator_password       = "D0ntL00kTh1sWay"
  },
  another_server = {
    machine_type                           = "db-custom-8-30720"
    storage_gb                             = 10
    backups_enabled                        = true
    backups_start_time                     = "21:00"
    backups_location                       = null
    backups_point_in_time_recovery_enabled = false
    backup_count                           = 7 # Number of backups to retain, not in days
    administrator_login                    = "pgadmin"
    administrator_password                 = "my$up3rS3cretPassw0rd"
    server_version                         = "13"
    availability_type                      = "ZONAL"
    ssl_enforcement_enabled                = true
    database_flags                         = [{ name = "foo" value = "true"}, { name = "bar", value = "false"}]
  }
}
```

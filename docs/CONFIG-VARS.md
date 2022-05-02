# List of valid configuration variables

Supported configuration variables are listed in the table below.  All variables can also be specified on the command line.  Values specified on the command line will override all values in configuration defaults files.

## Table of Contents

  - [Required Variables](#required-variables)
  - [Admin Access](#admin-access)
  - [Networking](#networking)
      - [Use Existing](#use-existing)
  - [General](#general)
  - [Nodepools](#nodepools)
    - [Default Nodepool](#default-nodepool)
    - [Additional Nodepools](#additional-nodepools)
  - [Storage](#storage)
  - [Postgres](#postgres)

Terraform input variables can be set in the following ways:
- Individually, with the [-var command line option](https://www.terraform.io/docs/configuration/variables.html#variables-on-the-command-line).
- In [variable definitions (.tfvars) files](https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files). We recommend this way for most variables.
- As [environment variables](https://www.terraform.io/docs/configuration/variables.html#environment-variables).

## Required Variables

| Name | Description | Type | Default | Notes |
| :--- | :--- | :--- | :--- | :--- |
| prefix | A prefix used in the name of all the resources created by this script. | string | | |
| ssh_public_key | Public ssh key for VMs | string | "~/.ssh/id_rsa.pub" | Value is required in order to access your VMs |

## General

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| kubernetes_version | The Machine cluster K8S version | string | "1.21" | Valid values are list here [Kubernetes Releases](https://kubernetes.io/releases/) |
| create_static_kubeconfig | Allows the user to create a provider / service account based kube config file | bool | false | A value of `false` will default to using the cloud providers mechanism for generating the kubeconfig file. A value of `true` will create a static kubeconfig which utilizes a `Service Account` and `Cluster Role Binding` to provide credentials. |
| jump_vm_admin | OS Admin User for the Jump VM | string | "jumpuser" | | |
| jump_rwx_filestore_path | File store mount point on Jump server | string | "/viya-share" | |
| tags | Map of common tags to be placed on all GCP resources created by this script | map | {} | |

## Nodepools

### Default Nodepool

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| default_nodepool_taints | Taints for the default nodepool VMs | list of strings | [] | |
| default_nodepool_labels | Labels to add to the default nodepool VMs | map | {} | |

### Additional Nodepools

Additional node pools can be created separate from the default nodepool. This is done with the `node_pools` variable which is a map of objects. Each nodepool requires the following variables:

| Name | Description | Type | Notes |
| :--- | ---: | ---: | ---: |
| node_taints | Taints for the nodepool VMs | list of strings | |
| node_labels | Labels to add to the nodepool VMs | map | |

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

## Postgres Servers

When setting up ***external database servers***, you must provide information about those servers in the `postgres_servers` variable block. Each entry in the variable block represents a ***single database server***.

This code only configures database servers. No databases are created during the infrastructure setup.

The variable has the following format:

```terraform
postgres_servers = {
  default = {},
  ...
}
```

**NOTE**: The `default = {}` elements is always required when creating external databases. This is the systems default database server.

Each server element, like `foo = {}`, can contain none, some, or all of the parameters listed below:

| Name | Description | Type | Default | Notes |
| :--- | ---: | ---: | ---: | ---: |
| administrator_login | The Administrator Login for the PostgreSQL Server. Changing this forces a new resource to be created. | string | "pgadmin" | | |
| administrator_password | The Password associated with the administrator_login for the PostgreSQL Server | string | "my$up3rS3cretPassw0rd" |  |
| server_version | The version of the  PostgreSQL server instance | string | "11" | Supported values are 11 and 12 |
| ssl_enforcement_enabled | Enforce SSL on connection to the PostgreSQL database | bool | true | |

Here is a sample of the `postgres_servers` variable with the `default` entry only overriding the `administrator_password` parameter and the `cps` entry overriding all of the parameters:

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

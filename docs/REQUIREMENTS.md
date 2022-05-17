# Open Source Infrastructure Requirements

The items listed below are designed to create a Highly Available (HA) infrastructure when creating your cluster on bare-metal or in a vCenter/vSphere environment. All of these items are REQUIRED as listed.

Table of Contents

<!-- vscode-markdown-toc -->
* 1. [Operating Systems](#OperatingSystems)
* 2. [Machines](#Machines)
	* 2.1. [vSphere](#vSphere)
		* 2.1.1. [Resources](#Resources)
		* 2.1.2. [Machine Template Requirements](#MachineTemplateRequirements)
	* 2.2. [Bare-Metal](#Bare-Metal)
* 3. [Network](#Network)
	* 3.1. [CIDR Block](#CIDRBlock)
	* 3.2. [Static IPs](#StaticIPs)
	* 3.3. [Floating IPs](#FloatingIPs)
* 4. [Examples](#Examples)
	* 4.1. [vCenter/vSphere Sample `tfvars` file](#vCentervSphereSampletfvarsfile)
	* 4.2. [Bare Metal Sample `inventory` file](#BareMetalSampleinventoryfile)
* 5. [Deployment](#Deployment)
* 6. [Tooling](#Tooling)

<!-- vscode-markdown-toc-config
	numbering=true
	autoSave=true
	/vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->

##  1. <a name='OperatingSystems'></a>Operating Systems

Supported operation systems that can be used in standing up infrastructure using this repo.

| OS | Description |
| --- | --- |
| [Ubuntu 20.04 LTS](https://releases.ubuntu.com/20.04/) | You must have a user with a password capable of unprompted `sudo` and have a shared `private/public` ssh key pair to use with each system. These are required for the Ansible tooling listed below |

##  2. <a name='Machines'></a>Machines

The following table lists the minimal machine requirements needed to support a kubernetes cluster and supporting elements for Viya 4 Software Installation. These machines will all need to be on the same network and each should have a DNS entry associated with it's assigned IP; however, this is not necessary, but does make setup easier.

**NOTE**: The PostgreSQL Server below is listed as 1 machine. If you are going to be using the internal PostgreSQL server of Viya this is not needed, but you will need to adjust your compute nodes capacity to ensure they can handle the needs of the postgres processes.

| Machine | CPU | Memory | Disk | IPs | Information | Minimum Count |
| ---: | ---: | ---: | ---: | ---: | --- | ---: |
| **Control Plane Node** | 8 | 16GiB | 100GiB | 1 | You must have an odd number of nodes here > 3 in order to provide High Availability (HA) for the cluster | 3 |
| **Compute Nodes** | 16 | 128GiB | 250GiB | 1 | Compute nodes in the kubernetes cluster | 6 |
| **Jump Server** | 4 | 8GiB | 100GiB | 1 | Bastian box used to access NFS mounts, share data, etc. | 1 |
| **NFS Server** | 8 | 16GiB | 500GiB | 1 | Server used to store Persistent Volumes for the cluster | 1 |
| **Postgres Servers** | 8 | 16GiB | 250GiB | 1 | PostgreSQL servers one may use with your Viya deployment. | 1..n |
| **TOTAL MINIMAL SYSTEM CAPACITY** | 140 | 856GiB | 2650GiB | 12 | | **12** |

###  2.1. <a name='vSphere'></a>vSphere

In order to leverage vSphere you'll need to have the following items for use in your tfvars file and `Administrator` access on vSphere.

####  2.1.1. <a name='Resources'></a>Resources

| vSphere Item | Description |
| --- | ---: |
|vsphere_cluster | Name of the vSphere cluster |
|vsphere_datacenter | Name of the vSphere data center |
|vsphere_datastore | Name of the vSphere data store to use for the VMs |
|vsphere_resource_pool | Name of the vSphere resource pool to use for the VMs |
|vsphere_folder | Name of the vSphere folder to store the vms |
|vsphere_template | Name of the VM template to clone to create VMs for the cluster |
|vsphere_network | Name of the vSphere network |

####  2.1.2. <a name='MachineTemplateRequirements'></a>Machine Template Requirements

The current repo supports the setup of vSphere VMs if the following are true

| Requirement | Description |
| --- | --- |
| Disk | The `root` partition `/` must be on `/dev/sd2` |
| Hard Disk | `Thin Provision` as the code here will adjust the size of the disk to match the machine requirement information above |

###  2.2. <a name='Bare-Metal'></a>Bare-Metal

For bare-metal provisioning you must set ALL systems with the required elements above. These systems must have full network access to one another.

##  3. <a name='Network'></a>Network

All systems need routable connectivity to one another.

###  3.1. <a name='CIDRBlock'></a>CIDR Block

CIDR block for your infrastructure it must be able to handle at least the 12 node machines outlined above, as well as the Virtual IP (VIP) used for the cluster entrypoint, and the cloud provider IP source range needed to support `LoadBalancer` services created.

###  3.2. <a name='StaticIPs'></a>Static IPs

These IPs are part of your network and will be assigned to the elements in this deployment.

* Control Plane Nodes
* Compute Nodes (Optional)
* LoadBalancer IP

###  3.3. <a name='FloatingIPs'></a>Floating IPs

These IPs are part of your network but are not assigned. The following items are needed.

* Compute Nodes
* Kubernetes Cluster Virtual IP (VIP)
* Floating LoadBalancer IPs for use with extra load balancers created.

##  4. <a name='Examples'></a>Examples

This section provides a `sample` configurations based on the bare-metal inventory and vsphere sample provided in this repo.

###  4.1. <a name='vCentervSphereSampletfvarsfile'></a>vCenter/vSphere Sample `tfvars` file

If you're creating virtual machines with vCenter/vSphere the `terraform.tfvars` file you create will generate the `inventory` and `ansible-vars.yaml` file needed for this repo.

For this example, the network setup for this sample are as follows:

```text
CIDR Range       : 10.18.0.0/16
VIP IP           : 10.18.0.175
LoadBalanced IPs : 10.18.0.100-10.18.0.125
```

Link to the file [`terraform.tfvars`](../examples/vsphere/terraform.tfvars)

```yaml
# Generic items
ansible_user     = "ansadmin"
ansible_password = "!Th!sSh0uldNotBUrP@ssw0rd#"
prefix           = "vm-dev" # Infra prefix
gateway          = "10.18.0.1" # Gateway for servers

# vSphere
vsphere_cluster       = "" # Name of the vSphere cluster
vsphere_datacenter    = "" # Name of the vSphere data center
vsphere_datastore     = "" # Name of the vSphere data store to use for the VMs
vsphere_resource_pool = "" # Name of the vSphere resource pool to use for the VMs
vsphere_folder        = "" # Name of the vSphere folder to store the vms
vsphere_template      = "" # Name of the VM template to clone to create VMs for the cluster
vsphere_network       = "" # Name of the network to to use for the VMs

# Systems
system_ssh_keys_dir = "~/.ssh" # Directory holding public keys to be used on each system

# Kubernetes - Cluster
cluster_version        = "1.21.11"                       # Kubernetes Version
cluster_cni            = "calico"                        # Kuberentes Container Network Interface (CNI)
cluster_cri            = "containerd"                    # Kubernetes Container Runtime Interface (CRI)
cluster_service_subnet = "10.35.0.0/16"                  # Kubernetes Service Subnet
cluster_pod_subnet     = "10.36.0.0/16"                  # Kubernetes Pod Subnet
cluster_domain         = "sample.domain.foo.com"         # Cluster domain suffix for DNS

# Kubernetes - Cluster VIP and Cloud Provider
kube_vip_version   = "0.4.4"
kube_vip_interface = "ens160"
kube_vip_ip        = "10.18.0.175"
kube_vip_dns       = "vm-dev-oss-vip.sample.domain.foo.com"
kube_vip_range     = "10.18.0.100-10.18.0.125"

# Control plane node specs
#   kube-vip - requires you have 3/5/7/9/... nodes for HA
#
#   Suggested node specs shown below. Entries for 3
#   IPs to support HA control plane
#
control_plane_num_cpu   = 8     # 8 CPUs
control_plane_ram       = 16384 # 16 GB 
control_plane_disk_size = 100   # 100 GB
control_plane_ips = [           # Assigned values For static IPs - for HA you need 3/5/7/9/... IPs
  "10.18.0.2",                  # Primary control plane node
  "10.18.0.3",                  # Secondary control plane node
  "10.18.0.4"                   # Secondary control plane node

]

# Compute node specs
#   node_count is used for dhcp and ips are used for static
#
#   Suggested node specs shown below. Entries for 6
#   IPs to support SAS Viya 4 deployment
#
node_num_cpu   = 16     # 16 CPUs
node_ram       = 131072 # 128 GB
node_disk_size = 250    # 256 GB
node_ips = [            # Assigned values for static IPs
  "10.18.0.5",          # Default/System node
  "10.18.0.6",          # CAS node
  "10.18.0.7",          # Generic node
  "10.18.0.8",          # Generic node
  "10.18.0.9",          # Generic node
  "10.18.0.10"          # Generic node
]

# Jump server
#
#   Suggested server specs shown below.
#
create_jump    = true         # Creation flag
jump_num_cpu   = 4            # 4 CPUs
jump_ram       = 8092         # 8 GB
jump_disk_size = 100          # 100 GB
jump_ip        = "10.18.0.11" # Assigned values for static IPs

# NFS server
#
#   Suggested server specs shown below.
#
create_nfs    = true         # Creation flag
nfs_num_cpu   = 8            # 8 CPUs
nfs_ram       = 16384        # 16 GB
nfs_disk_size = 500          # 500 GB
nfs_ip        = "10.18.0.12" # Assigned values for static IPs

# Postgres server
#
#   Suggested server specs shown below.
#
postgres_servers = {
  default = {
    server_num_cpu         = 8                       # 8 CPUs
    server_ram             = 16384                   # 16 GB
    server_disk_size       = 250                     # 256 GB
    server_ip              = "10.18.0.13"          # Assigned values for static IPs
    server_version         = 12                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
  }
}
```

###  4.2. <a name='BareMetalSampleinventoryfile'></a>Bare Metal Sample `inventory` file

With this example since you're utilizing bare-metal machines or pre-configured virtual machines (VMs) you'll need to populate the `inventory` file along with the `ansible-vars.yaml` file for you setup using the examples provided.

This example is using the `192.168.0.0/16` CIDR block for the cluster. The cluster's prefix is `viya4-oss`. The cluster VIP has been assigned IP `192.168.0.1`.

Link to the file [`inventory`](../examples/bare-metal/inventory)

```yaml
#
# Kubernetes - Control Plane nodes
#
# This list is the FQDN/IP of the nodes used for the control plane
#
# NOTE: For HA/kube-vip to work you need at least 3 nodes
#
[k8s_control_plane]
192.168.1.0
192.168.1.1
192.168.1.2

#
# Kubernetes - Compute nodes
#
# This list is the FQDN/IP of the nodes used for the compute nodes
#
# NOTE: For HA to work you need at least 3 nodes
#
[k8s_node]
192.168.2.0
192.168.2.1
192.168.2.2
192.168.2.3
192.168.2.4
192.168.2.5

#
# Kubernetes Nodes - alias - DO NOT MODIFY
#
[k8s:children]
k8s_control_plane
k8s_node

#
# Jump Server
#
[jump_server]
192.168.3.0

#
# Jump Server - alias - DO NOT MODIFY
#
[jump:children]
jump_server

#
# NFS Server
#
[nfs_server]
192.168.4.0

#
# NFS Server - alias - DO NOT MODIFY
#
[nfs:children]
nfs_server

#
# Postgres Servers
#
# NOTE: You MUST have an entry for each postgres server
#
[viya4_oss_default_pgsql]
192.168.5.0
[viya4_oss_default_pgsql:vars]
postgres_server_version=12
postgres_server_ssl=off                 # NOTE: Values - [on,off]
postgres_administrator_login="postgres" # NOTE: Do not change this value at this time
postgres_administrator_password="Un33d2ChgM3n0W!"

# NOTE: Add entries here for each postgres server listed above
[postgres:children]
viya4_oss_default_pgsql
```

Link to the file [`./examples/ansbile-vars-bare-metal.yaml`](../examples/bare-metal/ansible-vars.yaml)

```yaml
# Ansible items
ansible_user     : ""
ansible_password : ""

# VM items
vm_os   : "ubuntu" # Choices : [ubuntu|rhel] - Ubuntu 20.04 LTS / RHEL ???
vm_arch : "amd64"  # Choices : [amd64] - 64-bit OS / ???

# Misc. items
enable_cgroup_v2    : true     # TODO - If needed hookup or remove flag
system_ssh_keys_dir : "~/.ssh" # Directory holding public keys to be used on each system

# Kubernetes - Common
#
# TODO: kubernetes_upgrade_allowed needs to be implemented to either
#       add or remove locks on the kubeadm, kubelet, kubectl packages
#
kubernetes_cluster_name    : ""
kubernetes_version         : ""
kubernetes_upgrade_allowed : true
kubernetes_arch            : "{{ vm_arch }}"
kubernetes_cni             : "calico"        # Choices : [calico]
kubernetes_cri             : "containerd"    # Choices : [containerd|docker|cri-o] NOTE: cri-o is not currently functional
kubernetes_service_subnet  : ""
kubernetes_pod_subnet      : ""

# Kubernetes - VIP : https://kube-vip.io
# 
# Useful links:
#
#   VIP IP : https://kube-vip.chipzoller.dev/docs/installation/static/
#   VIP Cloud Provider IP Range : https://kube-vip.chipzoller.dev/docs/usage/cloud-provider/#the-kube-vip-cloud-provider-configmap
#
kubernetes_vip_version              : "0.4.4"
kubernetes_vip_interface            : "ens160"
kubernetes_vip_ip                   : ""
kubernetes_vip_loadbalanced_dns     : ""
kubernetes_vip_cloud_provider_range : ""

# Kubernetes - Control Plane
control_plane_ssh_key_name : "cp-ssh"

# Kubernetes - Compute Nodes

# Jump Server
jump_ip : ""

# NFS Server
nfs_ip  : ""

# Postgres Servers
```

##  5. <a name='Deployment'></a>Deployment

You'll need to add the following items to your `ansible-vars.yaml` if using the [viya4-deployment](https://github.com/sassoftware/viya4-deployment.git) repo.

```yaml
## 3rd Party

### Ingress Controller
INGRESS_NGINX_CHART_VERSION: 3.40.0
INGRESS_NGINX_CONFIG:

### Metrics Server
METRICS_SERVER_CHART_VERSION: 5.10.14
METRICS_SERVER_CONFIG:
  apiService:
    create: true
  extraArgs:
    kubelet-insecure-tls: true
    kubelet-preferred-address-types: InternalIP,ExternalIP,Hostname,InternalDNS,ExternalDNS
    kubelet-use-node-status-port: true
    requestheader-allowed-names: aggregator
    metric-resolution: 15s
    cert-dir: /tmp
  service:
    labels:
      kubernetes.io/cluster-service: "true"
      kubernetes.io/name: "Metrics-server"

### NFS Subdir External Provisioner - SAS default storage class
# Updates to support OSS Kubernetes 
NFS_CLIENT_NAME: nfs-subdir-external-provisioner-sas
NFS_CLIENT_CHART_VERSION: 4.0.15
```

##  6. <a name='Tooling'></a>Tooling

| Tooling | Minimal Version |
| ---: | ---: |
| [Ansible](https://www.ansible.com/) | Core 2.12.2 |
| [Terraform](https://www.terraform.io/) | 1.1.0 |
| [Docker](https://www.docker.com/) | 20.10.12 |
| [Helm](https://helm.sh/) | v3.8.2 |

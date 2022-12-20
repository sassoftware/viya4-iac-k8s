# General items
ansible_user     = ""
ansible_password = ""
prefix           = "v4-k8s-min" # Infra prefix
gateway          = ""           # Gateway for servers
netmask          = ""           # Network interface netmask

# vSphere
vsphere_server        = "" # Name of the vSphere server
vsphere_cluster       = "" # Name of the vSphere cluster
vsphere_datacenter    = "" # Name of the vSphere data center
vsphere_datastore     = "" # Name of the vSphere data store to use for the VMs
vsphere_resource_pool = "" # Name of the vSphere resource pool to use for the VMs
vsphere_folder        = "" # Name of the vSphere folder to store the vms
vsphere_template      = "" # Name of the VM template to clone to create VMs for the cluster
vsphere_network       = "" # Name of the network to to use for the VMs

# Systems
system_ssh_keys_dir = "~/.ssh/oss" # Directory holding public keys to be used on each system

# Kubernetes - Cluster
cluster_version        = "1.23.8"       # Kubernetes Version
cluster_cni            = "calico"       # Kuberentes Container Network Interface (CNI)
cluster_cni_version    = "3.24.5"       # Kubernetes Container Network Interface (CNI) Version
cluster_cri            = "containerd"   # Kubernetes Container Runtime Interface (CRI)
cluster_service_subnet = "10.43.0.0/16" # Kubernetes Service Subnet
cluster_pod_subnet     = "10.42.0.0/16" # Kubernetes Pod Subnet
cluster_domain         = ""             # Cluster domain suffix for DNS

# Kubernetes - Cluster VIP
cluster_vip_version = "0.5.7"
cluster_vip_ip      = ""
cluster_vip_fqdn    = ""

# Kubernetes - Load Balancer

# Load Balancer Type
cluster_lb_type = "kube_vip" # Load Balancer accepted values [kube_vip,metallb]

# Load Balancer Addresses
#
# Examples for each load balancer type can be found here:
#
#  kube-vip address format : https://kube-vip.io/docs/usage/cloud-provider/#the-kube-vip-cloud-provider-configmap
#  metallb address format  : https://metallb.universe.tf/configuration/#layer-2-configuration
#
#    kube-vip sample:
#
#      cluster_lb_addresses = [
#        "cidr-default: 192.168.0.200/29",                  # CIDR-based IP range for use in the default Namespace
#        "range-development: 192.168.0.210-192.168.0.219",  # Range-based IP range for use in the development Namespace
#        "cidr-finance: 192.168.0.220/29,192.168.0.230/29", # Multiple CIDR-based ranges for use in the finance Namespace
#        "cidr-global: 192.168.0.240/29"                    # CIDR-based range which can be used in any Namespace
#      ]
#
#    metallb sample:
#
#      cluster_lb_addresses = [
#        "192.168.10.0/24",
#        "192.168.9.1-192.168.9.5"
#      ]
#
#  NOTE: If you are assigning a static IP using the loadBalancerIP value for your 
#        load balancer controller service when using `metallb` that IP must fall
#        within the address range you provide below. If you are using `kube_vip`
#        you do not have this limitation.
#
cluster_lb_addresses = []

# Control plane node shared ssh key name
control_plane_ssh_key_name = "cp_ssh"

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
cluster_node_pool_mode = "minimal"
node_pools = {
  # REQUIRED NODE TYPE - DO NOT REMOVE and DO NOT CHANGE THE NAME
  #                      Other varaibles may be altered
  control_plane = {
    count       = 1
    cpus        = 2
    memory      = 4096
    os_disk     = 100
    node_taints = []
    node_labels = {}
  },
  # REQUIRED NODE TYPE - DO NOT REMOVE and DO NOT CHANGE THE NAME
  #                      Other varaibles may be altered
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
    count   = 3
    cpus    = 8
    memory  = 16384
    os_disk = 100
    misc_disks = [
      150,
      150,
    ]
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },
  generic = {
    count   = 5
    cpus    = 24
    memory  = 131072
    os_disk = 350
    misc_disks = [
      150,
    ]
    node_taints = []
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  }
}

# Jump server
create_jump    = true # Creation flag
jump_num_cpu   = 4    # 4 CPUs
jump_memory    = 8092 # 8 GB
jump_disk_size = 100  # 100 GB
jump_ip        = ""   # Assigned values for static IPs

# NFS server
create_nfs    = true  # Creation flag
nfs_num_cpu   = 8     # 8 CPUs
nfs_memory    = 16384 # 16 GB
nfs_disk_size = 500   # 500 GB
nfs_ip        = ""    # Assigned values for static IPs

# Container Registry
create_cr    = false # Creation flag
cr_num_cpu   = 4     # 4 CPUs
cr_memory    = 8092  # 8 GB
cr_disk_size = 250   # 250 GB
cr_ip        = ""    # Assigned values for static IPs

# Postgres Servers
postgres_servers = {
  default = {
    server_num_cpu         = 8                       # 8 CPUs
    server_memory          = 16384                   # 16 GB
    server_disk_size       = 250                     # 256 GB
    server_ip              = ""                      # Assigned values for static IPs
    server_version         = 13                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
  }
}

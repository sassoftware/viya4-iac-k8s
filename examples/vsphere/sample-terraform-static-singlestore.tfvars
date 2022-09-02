# General items
ansible_user     = ""
ansible_password = ""
prefix           = "v4-k8s-static" # Infra prefix
gateway          = ""              # Gateway for servers
netmask          = ""              # Needed for any network outside the 10.12.0 location

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
cluster_version        = "1.23.8"      # Kubernetes Version
cluster_cni            = "calico"       # Kuberentes Container Network Interface (CNI)
cluster_cri            = "containerd"   # Kubernetes Container Runtime Interface (CRI)
cluster_service_subnet = "10.43.0.0/16" # Kubernetes Service Subnet
cluster_pod_subnet     = "10.42.0.0/16" # Kubernetes Pod Subnet
cluster_domain         = ""             # Cluster domain suffix for DNS

# Kubernetes - Cluster VIP and Cloud Provider
kube_vip_version   = "0.5.0"
kube_vip_interface = ""
kube_vip_ip        = ""
kube_vip_dns       = ""
kube_vip_range     = ""

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
node_pools = {
  # REQUIRED NODE TYPE - DO NOT REMOVE and DO NOT CHANGE THE NAME
  #                      Other varaibles may be altered
  control_plane = {
    cpus    = 2
    memory  = 4096
    os_disk = 100
    ip_addresses = [
      "",
      "",
      "",
    ]
    node_taints = []
    node_labels = {}
  },
  # REQUIRED NODE TYPE - DO NOT REMOVE and DO NOT CHANGE THE NAME
  #                      Other varaibles may be altered
  system = {
    cpus    = 8
    memory  = 16384
    os_disk = 100
    ip_addresses = [
      "",
    ]
    node_taints = []
    node_labels = {
      "kubernetes.azure.com/mode" = "system" # REQUIRED LABEL - DO NOT REMOVE
    }
  },
  cas = {
    cpus    = 16
    memory  = 131072
    os_disk = 350
    misc_disks = [
      150,
      150,
    ]
    ip_addresses = [
      "",
      "",
      "",
    ]
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },
  compute = {
    cpus    = 16
    memory  = 131072
    os_disk = 100
    ip_addresses = [
      "",
    ]
    node_taints = ["workload.sas.com/class=compute:NoSchedule"]
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  },
  stateful = {
    cpus    = 8
    memory  = 32768
    os_disk = 100
    misc_disks = [
      150,
    ]
    ip_addresses = [
      "",
    ]
    node_taints = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateful"
    }
  },
  stateless = {
    cpus    = 8
    memory  = 32768
    os_disk = 100
    misc_disks = [
      150,
    ]
    ip_addresses = [
      "",
      "",
    ]
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
      150,
      150,
      250,
      250,
    ]
    ip_addresses = [
      "",
      "",
      "",
    ]
    node_taints = ["workload.sas.com/class=singlestore:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "singlestore"
    }
  }
}

# Jump server
create_jump    = true          # Creation flag
jump_num_cpu   = 4             # 4 CPUs
jump_memory    = 8092          # 8 GB
jump_disk_size = 100           # 100 GB
jump_ip        = "10.12.50.30" # Assigned values for static IPs

# NFS server
create_nfs    = true          # Creation flag
nfs_num_cpu   = 8             # 8 CPUs
nfs_memory    = 16384         # 16 GB
nfs_disk_size = 500           # 500 GB
nfs_ip        = "10.12.50.31" # Assigned values for static IPs

# Postgres Servers
postgres_servers = {
  default = {
    server_num_cpu         = 8                       # 8 CPUs
    server_memory          = 16384                   # 16 GB
    server_disk_size       = 250                     # 256 GB
    server_ip              = "10.12.50.32"           # Assigned values for static IPs
    server_version         = 12                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
  }
}

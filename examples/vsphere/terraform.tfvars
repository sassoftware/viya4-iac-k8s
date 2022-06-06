# General items
ansible_user     = ""
ansible_password = ""
prefix           = "" # Infra prefix
gateway          = "" # Gateway for servers
netmask          = "" # Netmask providing network access to your gateway

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
system_ssh_keys_dir = "" # Directory holding public keys to be used on each system

# Kubernetes - Cluster
cluster_version        = "" # Kubernetes Version
cluster_cni            = "" # Kuberentes Container Network Interface (CNI)
cluster_cri            = "" # Kubernetes Container Runtime Interface (CRI)
cluster_service_subnet = "" # Kubernetes Service Subnet
cluster_pod_subnet     = "" # Kubernetes Pod Subnet
cluster_domain         = "" # Cluster domain suffix for DNS

# Kubernetes - Cluster VIP and Cloud Provider
kube_vip_version   = "0.4.4" # kube-vip version
kube_vip_interface = ""      # kube-vip interface
kube_vip_ip        = ""      # kube-vip ip
kube_vip_dns       = ""      # kube-vip dns
kube_vip_range     = ""      # kube-vip ip range

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
  "",
  "",
  ""
]
control_plane_ssh_key_name = "" # Name for generated control plane ssh key

# Node specs
#   node_count is used for dhcp and ips are used for static
#
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

# Jump server
create_jump    = true # Creation flag
jump_num_cpu   = 4    # 4 CPUs
jump_ram       = 8092 # 8 GB
jump_disk_size = 100  # 100 GB
jump_ip        = ""   # Assigned values for static IPs

# NFS server
create_nfs    = true  # Creation flag
nfs_num_cpu   = 8     # 8 CPUs
nfs_ram       = 16384 # 16 GB
nfs_disk_size = 500   # 500 GB
nfs_ip        = ""    # Assigned values for static IPs

# Postgres Servers
postgres_servers = {
  default = {
    server_num_cpu         = 8                       # 8 CPUs
    server_ram             = 16384                   # 16 GB
    server_disk_size       = 250                     # 256 GB
    server_ip              = ""                      # Assigned values for static IPs
    server_version         = 12                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "my$up3rS3cretPassw0rd" # PostgreSQL admin user password
  }
}

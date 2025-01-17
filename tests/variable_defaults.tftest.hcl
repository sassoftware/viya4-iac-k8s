# Description: This terraform test file checks the default values for variables in the variables.tf file. 
# The variables are used to define the configuration of the virtual machines that will be created in the vSphere environment.
#
# The tests check the default values for the following variables:
#
# - cluster_cni
# - cluster_cni_version
#
# The test checks that the default values for the variables match the expected values.
#
# The expected values are:
# - cluster_cni: "calico"
# - cluster_cni_version: "3.29.0"
# 
# In order to run this test, the following environment variables must be exported to the shell where the test is run:
# - vsphere_server
# - vsphere_username
# - vsphere_password
#
#  The following statements are an example of how to export the environment variables prior to running the test:
#
# export TF_VAR_vsphere_user=****
# export TF_VAR_vsphere_password=****
# export TF_VAR_vsphere_server=vcenter*.*.*.*
#
# Be sure to fill in the configured VSphere values for the _REPLACE_ME_ placeholders in the vSphere variables section below.
#
# The test can be executed by running the following command in the root directory of the repository:
# terraform test --verbose --filter=tests/variable_defaults.tftest.hcl


variables {

deployment_type = "vsphere"

# General items
ansible_user     = "ubuntu"
ansible_password = "ubuntu"
prefix           = "prefix14"  # Infra prefix TODO REPLACE ME
gateway          = "10.124.93.1" # Gateway for servers
netmask          = "24"          # Network interface netmask

# vSphere
# TODO: Replace the first three values below with the correct values for your configured VSphere environment
vsphere_server        = "_REPLACE_ME_" # Name of the vSphere server
vsphere_datacenter    = "_REPLACE_ME_" # Name of the vSphere data center
vsphere_datastore     = "_REPLACE_ME_" # Name of the vSphere data store to use for the VMs
vsphere_resource_pool = "viya4-iac-k8s-testing-resource-pool" # Name of the vSphere resource pool to use for the VMs
vsphere_folder        = "Infrastructure as Code/Users/nobody" # Name of the vSphere folder to store the vms TODO REPLACE ME, use your own folder
vsphere_template      = "ubuntu_22.04_LTS" # Name of the VM template to clone to create VMs for the cluster TODO REPLACE ME, optional ubuntu_20.04_LTS is also available
vsphere_network       = "IACdhcp" # Name of the network to to use for the VMs

# Systems
system_ssh_keys_dir = "/workspace/.ssh" # Directory holding public keys to be used on each system, TODO REPLACE ME your path may differ

# Kubernetes - Cluster
cluster_version        = "1.30.4"       # Kubernetes Version
# The next two lines are intentionally commented out to test the assigned default values
#cluster_cni            = "calico"       # Kubernetes Container Network Interface (CNI)
#cluster_cni_version    = "3.29.0"       # Kubernetes Container Network Interface (CNI) Version
cluster_cri            = "containerd"   # Kubernetes Container Runtime Interface (CRI)
cluster_cri_version    = "1.7.24"       # Kubernetes Container Runtime Interface (CRI) Version
cluster_service_subnet = "10.43.0.0/16" # Kubernetes Service Subnet
cluster_pod_subnet     = "10.42.0.0/16" # Kubernetes Pod Subnet
cluster_domain         = "sas.com"   # Cluster domain suffix for DNS

# Kubernetes - Cluster VIP
cluster_vip_version = "0.7.1"
cluster_vip_ip      = "10.124.93.221" # TODO REPLACE ME, put the first IP of the contiguous block your reserved earlier
cluster_vip_fqdn    = "host.sas.com" # TODO REPLACE ME, put the fqdn of the first IP of the contiguous block your reserved earlier

# Kubernetes - Load Balancer

# Load Balancer Type
cluster_lb_type = "kube_vip" # Load Balancer accepted values [kube_vip,metallb]

# Load Balancer Addresses
#
# Examples for each load balancer type can be found here:
#
#  kube-vip address format : https://kube-vip.io/docs/usage/cloud-provider/#the-kube-vip-cloud-provider-configmap
#  MetalLB address format  : https://metallb.universe.tf/configuration/#layer-2-configuration
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
#    MetalLB sample:
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
#cluster_lb_addresses = []
#kube-vip
cluster_lb_addresses = [
  "range-global: 10.124.93.222-10.124.93.223", # Range-based IP range for use in the development Namespace  # TODO REPLACE ME, range of the second and third IP of the contiguous block you reserved earlier.
]

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
  #                      Other variables may be altered
  control_plane = {
    count       = 3
    cpus        = 2
    memory      = 4096
    os_disk     = 100
    node_taints = []
    node_labels = {}
  },
  # REQUIRED NODE TYPE - DO NOT REMOVE and DO NOT CHANGE THE NAME
  #                      Other variables may be altered
  system = {
    count       = 1
    cpus        = 8
    memory      = 65536
    os_disk     = 100
    node_taints = []
    node_labels = {
      "kubernetes.azure.com/mode" = "system" # REQUIRED LABEL - DO NOT REMOVE
    }
  },
  cas = {
    count      = 3
    cpus       = 16
    memory     = 131072
    os_disk    = 350
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
    count      = 1
    cpus       = 8
    memory     = 32768
    os_disk    = 100
    misc_disks = [
      150,
    ]
    node_taints = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateful"
    }
  },
  stateless = {
    count      = 2
    cpus       = 8
    memory     = 32768
    os_disk    = 100
    misc_disks = [
      150,
    ]
    node_taints = ["workload.sas.com/class=stateless:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateless"
    }
  }
}

# Jump server
create_jump    = true # Creation flag
jump_num_cpu   = 4    # 4 CPUs
jump_memory    = 8092 # 8 GB
jump_disk_size = 100  # 100 GB
jump_ip        = "10.124.93.143"   # Assigned values for static IPs # TODO REPLACE ME, use reserved jump IP

# NFS server
create_nfs    = true  # Creation flag
nfs_num_cpu   = 4     # 4 CPUs
nfs_memory    = 16384 # 16 GB
nfs_disk_size = 400   # 400 GB
nfs_ip        = "10.124.93.67"    # Assigned values for static IPs # TODO REPLACE ME, use reserved nfs IP

# Postgres Servers
postgres_servers = {
  default = {
    server_num_cpu         = 4                       # 4 CPUs
    server_memory          = 16384                   # 16 GB
    server_disk_size       = 128                     # 128 GB
    server_ip              = "10.124.93.126"                      # Assigned values for static IPs # TODO REPLACE ME, use reserved nfs IP
    server_version         = 15                      # PostgreSQL version
    server_ssl             = "off"                   # SSL flag
    administrator_login    = "postgres"              # PostgreSQL admin user - CANNOT BE CHANGED
    administrator_password = "S3cretPassw0rd" # PostgreSQL admin user password
  }
}

}

run "cluster_cni_should_default_to_calico" {

  command = plan
  
  variables {
  }

  assert {
    condition     = var.cluster_cni == "calico"
    error_message = "A default value of \"${var.cluster_cni}\" for cluster_cni was not expected."
  }
}

run "cluster_cni_version_should_default_to_3_29_0" {

  command = plan
  
  variables {
  }

  assert {
    condition     = var.cluster_cni_version == "3.29.0"
    error_message = "A default value of \"${var.cluster_cni_version}\" for cluster_cni_version was not expected."
  }
}

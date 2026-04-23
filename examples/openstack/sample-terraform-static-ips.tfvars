# =============================================================================
# Sample tfvars for deploying a SAS Viya 4 Kubernetes cluster on OpenStack
# using pre-assigned static (fixed) IP addresses.
#
# Use this variant when your OpenStack tenant uses static / SDN-assigned IPs
# and you do NOT want floating IPs attached to every node.
#
# Copy this file, fill in the values, and run:
#   terraform init
#   terraform plan -var-file=<your-file>.tfvars
#   terraform apply -var-file=<your-file>.tfvars
# =============================================================================

# Deployment type - DO NOT CHANGE
deployment_type = "openstack"

# General items
ansible_user     = ""          # OS user for Ansible SSH access (e.g. ubuntu)
ansible_password = ""          # Leave empty if using SSH key-based auth
prefix           = "v4-k8s-os" # Infra prefix – lowercase alphanumeric + hyphens

# OpenStack credentials / endpoint
openstack_auth_url    = "" # e.g. https://openstack.example.com:5000/v3
openstack_user_name   = "" # OpenStack username
openstack_password    = "" # OpenStack password
openstack_tenant_name = "" # Project / tenant name
openstack_domain_name = "Default"
openstack_region      = "" # e.g. RegionOne
openstack_insecure    = false
# openstack_cacert_file = "/path/to/ca.crt"

# OpenStack compute / network settings
openstack_image_name        = "" # e.g. "Ubuntu 22.04 LTS"
openstack_network_name      = "" # Internal Neutron network name
openstack_floating_ip_pool  = null # Set to null – no floating IPs in static mode
openstack_ssh_keypair       = "" # Name of the Nova keypair
openstack_security_groups   = ["default", "k8s"]
openstack_availability_zone = "nova"

# Default Nova flavor
openstack_flavor_defaults = "m1.large"

# Systems
system_ssh_keys_dir = "~/.ssh/oss"

# Kubernetes - Cluster
cluster_version        = "1.32.7"
cluster_cni            = "calico"
cluster_cni_version    = "3.30.0"
cluster_cri            = "containerd"
cluster_cri_version    = "1.7.24"
cluster_service_subnet = "10.43.0.0/16"
cluster_pod_subnet     = "10.42.0.0/16"
cluster_domain         = ""             # Base DNS domain for this cluster's nodes.
                                            # Nodes will be registered as <hostname>.<cluster_domain>.
                                            # Use the domain that matches your OpenStack tenant's DNS zone.
                                            # HPOS example: clt-jk1.hpos4.rnd.sas.com
                                            # Leave empty to default to cluster.local (not recommended for HPOS).

# Kubernetes - Cluster VIP
cluster_vip_version = "0.7.1"
cluster_vip_ip      = ""
cluster_vip_fqdn    = ""

# Kubernetes - Load Balancer
cluster_lb_type      = "kube_vip"
cluster_lb_addresses = []

# Control plane SSH key name
control_plane_ssh_key_name = "cp_ssh"

# =============================================================================
# Cluster Node Pools – with static ip_addresses
#
# Provide one IP per instance.  The number of IPs determines instance_count.
#
# - flavor     : (optional) override openstack_flavor_defaults for this pool
# - os_disk    : root volume size in GiB for the boot/OS disk.
#                This is a Cinder (block storage) volume — it is NOT limited to
#                the flavor's ephemeral disk size. It is created independently
#                and can be sized based on available Cinder quota.
#                Recommended minimums: control_plane=100, system=100,
#                                      node=350 (for Viya workloads), others=100
# - misc_disks : list of additional Cinder data volume sizes in GiB (e.g. [100, 200])
# =============================================================================
node_pools = {
  # REQUIRED – DO NOT REMOVE or RENAME
  control_plane = {
    flavor  = "m1.medium"
    os_disk = 100
    ip_addresses = [
      "", # control-plane node 1
      "", # control-plane node 2
      "", # control-plane node 3
    ]
    node_taints = []
    node_labels = {}
  },
  # REQUIRED – DO NOT REMOVE or RENAME
  system = {
    flavor  = "m1.xlarge"
    os_disk = 100
    ip_addresses = [
      "", # system node 1
    ]
    node_taints = []
    node_labels = {
      "kubernetes.azure.com/mode" = "system"
    }
  },
  cas = {
    flavor  = "m1.2xlarge"
    os_disk = 350
    misc_disks = [150, 150]
    ip_addresses = [
      "", # cas node 1
      "", # cas node 2
      "", # cas node 3
    ]
    node_taints = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },
  compute = {
    flavor  = "m1.2xlarge"
    os_disk = 100
    ip_addresses = [
      "", # compute node 1
    ]
    node_taints = ["workload.sas.com/class=compute:NoSchedule"]
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  },
  stateful = {
    flavor  = "m1.large"
    os_disk = 100
    misc_disks = [150]
    ip_addresses = [
      "", # stateful node 1
      "", # stateful node 2
    ]
    node_taints = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateful"
    }
  },
  stateless = {
    flavor  = "m1.large"
    os_disk = 100
    misc_disks = [150]
    ip_addresses = [
      "", # stateless node 1
      "", # stateless node 2
      "", # stateless node 3
      "", # stateless node 4
    ]
    node_taints = ["workload.sas.com/class=stateless:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateless"
    }
  }
}

# Jump server
create_jump    = true
jump_num_cpu   = 4
jump_memory    = 8092
jump_disk_size = 100
jump_ip        = "" # Static IP for jump server

# NFS server
create_nfs    = true
nfs_num_cpu   = 4
nfs_memory    = 16384
nfs_disk_size = 400
nfs_ip        = "" # Static IP for NFS server

# Postgres Servers
postgres_servers = {
  default = {
    server_disk_size       = 128
    server_ip              = "" # Static IP for Postgres server
    server_version         = 15
    server_ssl             = "off"
    administrator_login    = "postgres"
    administrator_password = "my$up3rS3cretPassw0rd"
  }
}

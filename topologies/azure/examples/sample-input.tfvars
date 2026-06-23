# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Azure Topology — Full Node Pool Input Variables
# =============================================================================
# This file provides a production-grade node pool configuration with dedicated
# pools for each SAS Viya workload class:
#   cas        — CAS in-memory analytics server
#   compute    — SAS Compute / programming environment
#   stateless  — Stateless SAS microservices
#   stateful   — Stateful SAS services (e.g. SAS Infrastructure Data Server)
#
# For a minimal/starter configuration, see sample-input-minimal.tfvars instead.
#
# Usage (recommended — copy to repo root and rename):
#   cp topologies/azure/examples/sample-input.tfvars terraform-azure.tfvars
#   # Edit terraform-azure.tfvars with your values, then:
#   export SYSTEM=azure
#   ./scripts/deploy.sh apply setup install
#
# Usage (from repo root with explicit var-file):
#   terraform -chdir=topologies/azure init
#   terraform -chdir=topologies/azure plan  -var-file="examples/sample-input.tfvars"
#   terraform -chdir=topologies/azure apply -var-file="examples/sample-input.tfvars"
# =============================================================================

# =====================================
# REQUIRED VARIABLES
# =====================================

# Deployment type — selects which topology module is used at the root level
deployment_type = "azure"

tags = {
  "resourceowner" = "your.name@example.com"
  "project"       = "sas-viya4-k8s"
}

# Azure resource settings
azure_resource_group = "my-k8s-rg"
azure_location       = "eastus"

# Cluster prefix — used in naming all cloud resources
prefix = "my-k8s"

# SSH public key for VM access
ssh_public_key = "~/.ssh/id_rsa.pub"

# Azure Authentication — DO NOT COMMIT SECRETS TO VERSION CONTROL
# Recommended: set via environment variables before running deploy.sh or docker:
#
#   export TF_VAR_azure_subscription_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_tenant_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_client_id="00000000-0000-0000-0000-000000000000"
#   export TF_VAR_azure_client_secret="your-secret-here"
#
#   # Also export ARM_* so Ansible picks them up for the Azure CCM DaemonSet:
#   export ARM_SUBSCRIPTION_ID="$TF_VAR_azure_subscription_id"
#   export ARM_TENANT_ID="$TF_VAR_azure_tenant_id"
#   export ARM_CLIENT_ID="$TF_VAR_azure_client_id"
#   export ARM_CLIENT_SECRET="$TF_VAR_azure_client_secret"
#
# Or use Managed Identity (when running on an Azure VM):
#   azure_use_msi = true

azure_use_msi = false

# =====================================
# NETWORKING
# =====================================

azure_vnet_address_space = "192.168.0.0/16"

azure_subnets = {
  k8s = {
    prefixes          = ["192.168.0.0/22"]
    service_endpoints = []
  }
  misc = {
    prefixes          = ["192.168.4.0/24"]
    service_endpoints = []
  }
}

# Security — restrict access to your IPs/CIDRs (SSH and Kubernetes API)
azure_default_public_access_cidrs = [
  # "203.0.113.0/24"   # Your office/VPN network
  # "198.51.100.42/32" # Your workstation
]

azure_vm_public_ip_enabled   = true
azure_accelerated_networking = true
azure_create_nsg_rules       = true

# =====================================
# CLUSTER NODE POOLS
# =====================================
# Dedicated node pools per SAS Viya workload class.
# Adjust machine_type and count to match your sizing requirements.
# See: https://go.documentation.sas.com/doc/en/itopscdc/default/dplyml0phy0dkr/p04q4t7qp6n2gqn1gqtlh5ylvlox.htm

node_pools = {
  control_plane = {
    count        = 3    # Odd number (1 or 3) for HA etcd quorum
    machine_type = "Standard_D4s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = ["node-role.kubernetes.io/control-plane:NoSchedule"]
    node_labels  = {}
  },
  system = {
    count        = 1
    machine_type = "Standard_D8s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = []
    node_labels = {
      "kubernetes.azure.com/mode" = "system"
    }
  },

  # ---- SAS Viya Workload Node Pools ----

  # CAS: in-memory analytics server
  cas = {
    count        = 1
    machine_type = "Standard_E16s_v5"
    os_disk      = 200
    data_disks   = []
    node_taints  = ["workload.sas.com/class=cas:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "cas"
    }
  },

  # Compute: SAS Compute server / programming environment
  compute = {
    count        = 1
    machine_type = "Standard_D16s_v5"
    os_disk      = 200
    data_disks   = []
    node_taints  = ["workload.sas.com/class=compute:NoSchedule"]
    node_labels = {
      "workload.sas.com/class"        = "compute"
      "launcher.sas.com/prepullImage" = "sas-programming-environment"
    }
  },

  # Stateless: stateless SAS microservices (e.g. Visual Analytics, APIs)
  stateless = {
    count        = 2
    machine_type = "Standard_D8s_v5"
    os_disk      = 200
    data_disks   = []
    node_taints  = ["workload.sas.com/class=stateless:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateless"
    }
  },

  # Stateful: stateful SAS services (e.g. SAS Infrastructure Data Server, Redis)
  stateful = {
    count        = 1
    machine_type = "Standard_D8s_v5"
    os_disk      = 200
    data_disks   = []
    node_taints  = ["workload.sas.com/class=stateful:NoSchedule"]
    node_labels = {
      "workload.sas.com/class" = "stateful"
    }
  }
}

# =====================================
# INFRASTRUCTURE VMs
# =====================================

create_jump       = true
jump_machine_type = "Standard_B2s"
jump_os_disk      = 64

create_nfs       = true
nfs_machine_type = "Standard_D4s_v5"
nfs_os_disk      = 100
nfs_data_disks   = [256, 256, 256, 256]   # 4 disks → RAID5 LVM via Ansible

# =====================================
# KUBERNETES CONFIGURATION
# =====================================

cluster_version     = "1.35"
azure_ccm_version   = "1.33.1"    # Azure CCM — released independently of Kubernetes

cluster_cni         = "calico"
cluster_cni_version = "3.30.3"
cluster_cri         = "containerd"
cluster_cri_version = "1.7.24"

cluster_service_subnet = "10.43.0.0/16"
cluster_pod_subnet     = "10.42.0.0/16"

# In-cluster service load balancer type: kube_vip (default) or metallb
cluster_lb_type = "kube_vip"

# Azure Internal Standard LB frontend IP — used as controlPlaneEndpoint for HA.
# Must be a free IP inside the k8s subnet (192.168.0.0/22). Default is 192.168.0.100.
# cluster_api_internal_ip = "192.168.0.100"

# kube-vip VIP — static IP from the misc subnet, not allocated to any VM
# cluster_vip_ip   = "192.168.4.100"
# cluster_vip_fqdn = "k8s.example.com"

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# ==========================================
# Azure Resource Group
# ==========================================

resource "azurerm_resource_group" "main" {
  name     = var.azure_resource_group
  location = var.azure_location
  tags     = var.tags
}

# ==========================================
# Azure Network
# ==========================================

module "azure_network" {
  source = "./modules/azure_network"

  prefix              = var.prefix
  resource_group_name = var.azure_resource_group
  location            = var.azure_location

  vnet_name                = var.azure_vnet_name
  vnet_resource_group_name = var.azure_vnet_resource_group_name
  vnet_address_space       = [var.azure_vnet_address_space]

  existing_subnet_names = var.azure_subnet_names
  subnets               = var.azure_subnets

  nsg_name         = var.azure_nsg_name
  misc_nsg_name    = var.azure_misc_nsg_name
  create_nsg_rules = var.azure_create_nsg_rules

  ssh_source_cidrs        = try(length(var.azure_vm_public_access_cidrs) > 0, false) ? var.azure_vm_public_access_cidrs : var.azure_default_public_access_cidrs
  api_server_source_cidrs = try(length(var.azure_cluster_endpoint_public_access_cidrs) > 0, false) ? var.azure_cluster_endpoint_public_access_cidrs : var.azure_default_public_access_cidrs
  nodeport_source_cidrs   = []

  dns_servers = var.azure_use_custom_dns ? var.azure_custom_dns_servers : []

  tags = var.tags

  depends_on = [azurerm_resource_group.main]
}

# ==========================================
# Azure VM Deployment (Kubernetes Nodes)
# ==========================================

module "azure_vms" {
  for_each = local.azure_vms_flat

  source = "./modules/azure_vm"

  vm_name                = each.value.vm_name
  resource_group_name    = var.azure_resource_group
  azure_location         = var.azure_location
  vm_size                = each.value.machine_type
  subnet_id              = module.azure_network.subnet_ids["k8s"]
  nsg_id                 = module.azure_network.nsg_id
  create_nsg_association = true
  ssh_public_key         = file(var.ssh_public_key)
  admin_username         = "azureuser"

  os_disk_size           = each.value.os_disk
  data_disk_sizes        = each.value.data_disks
  assign_public_ip       = false
  accelerated_networking = var.azure_accelerated_networking

  node_taints = each.value.node_taints
  node_labels = each.value.node_labels

  tags = merge(
    var.tags,
    {
      Name     = each.value.vm_name
      NodeType = each.value.pool_name
      NodePool = each.value.pool_name
      Cluster  = local.cluster_name
    }
  )

  depends_on = [module.azure_network]
}

# ==========================================
# Azure Standard Load Balancer for Kubernetes API Server
# ==========================================
# Creates a public Standard LB in front of control plane nodes.
# This provides:
#   - Stable public endpoint for kubectl access from anywhere
#   - HA across multiple control plane nodes
#   - Static kubeconfig usable from outside the VNet

module "azure_api_lb" {
  source = "./modules/azure_api_lb"

  prefix              = var.prefix
  resource_group_name = var.azure_resource_group
  location            = var.azure_location
  api_server_port     = 6443
  create_public_ip    = true
  create_internal_lb  = local.control_plane_node_count > 1
  subnet_id           = module.azure_network.subnet_ids["k8s"]
  internal_lb_ip      = var.cluster_api_internal_ip

  # Map of control plane node name -> NIC ID
  control_plane_nic_ids = {
    for key, vm in module.azure_vms : key => vm.network_interface_id
    if startswith(key, "control_plane-")
  }

  tags = var.tags

  depends_on = [module.azure_vms]
}

# ==========================================
# Jump Server
# ==========================================

module "azure_jump" {
  count = var.create_jump ? 1 : 0

  source = "./modules/azure_vm"

  vm_name                = "${local.cluster_name}-jump"
  resource_group_name    = var.azure_resource_group
  azure_location         = var.azure_location
  vm_size                = var.jump_machine_type
  subnet_id              = module.azure_network.subnet_ids["misc"]
  nsg_id                 = module.azure_network.nsg_misc_id
  create_nsg_association = true
  ssh_public_key         = file(var.ssh_public_key)
  admin_username         = "jumpuser"

  os_disk_size           = var.jump_os_disk
  data_disk_sizes        = []
  assign_public_ip       = var.azure_vm_public_ip_enabled
  accelerated_networking = false

  node_taints = []
  node_labels = {}

  tags = merge(
    var.tags,
    {
      Name    = "${local.cluster_name}-jump"
      Role    = "jump-box"
      Cluster = local.cluster_name
    }
  )

  depends_on = [module.azure_network]
}

# ==========================================
# NFS Server
# ==========================================

module "azure_nfs" {
  count = var.create_nfs ? 1 : 0

  source = "./modules/azure_vm"

  vm_name                = "${local.cluster_name}-nfs"
  resource_group_name    = var.azure_resource_group
  azure_location         = var.azure_location
  vm_size                = var.nfs_machine_type
  subnet_id              = module.azure_network.subnet_ids["misc"]
  nsg_id                 = module.azure_network.nsg_misc_id
  create_nsg_association = true
  ssh_public_key         = file(var.ssh_public_key)
  admin_username         = "nfsuser"

  os_disk_size           = var.nfs_os_disk
  data_disk_sizes        = var.nfs_data_disks
  assign_public_ip       = false
  accelerated_networking = var.azure_accelerated_networking

  node_taints = []
  node_labels = {}

  tags = merge(
    var.tags,
    {
      Name    = "${local.cluster_name}-nfs"
      Role    = "nfs-server"
      Cluster = local.cluster_name
    }
  )

  depends_on = [module.azure_network]
}

# ==========================================
# Generated Files (Ansible inventory + vars)
# ==========================================

resource "local_file" "inventory" {
  filename = var.inventory
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    prefix            = replace(var.prefix, "-", "_")
    control_plane_ips = length(local.azure_control_plane_ips) > 0 ? local.azure_control_plane_ips : []
    node_ips          = length(local.azure_node_ips) > 0 ? local.azure_node_ips : []
    nfs_ip            = local.azure_nfs_ip
    jump_ip           = local.azure_jump_ip
    jump_public_ip    = local.azure_jump_public_ip
    cr_ip             = var.create_cr ? var.cr_ip : null
    postgres_servers  = local.postgres_servers
  })
}

resource "local_file" "ansible_vars" {
  filename = var.ansible_vars
  content = templatefile("${path.module}/templates/ansible-vars.yaml.tmpl", {
    deployment_type            = var.deployment_type
    iac_tooling                = var.iac_tooling
    prefix                     = var.prefix
    cluster_name               = local.cluster_name
    cluster_version            = var.cluster_version
    azure_ccm_version          = var.azure_ccm_version
    cluster_cni                = var.cluster_cni
    cluster_cni_version        = var.cluster_cni_version
    cluster_cri                = var.cluster_cri
    cluster_cri_version        = var.cluster_cri_version
    cluster_service_subnet     = var.cluster_service_subnet
    cluster_pod_subnet         = var.cluster_pod_subnet
    cluster_dns_ip             = local.cluster_dns_ip
    control_plane_ssh_key_name = var.control_plane_ssh_key_name
    cluster_vip_version        = var.cluster_vip_version
    cluster_vip_ip             = var.cluster_vip_ip != null ? var.cluster_vip_ip : ""
    cluster_vip_fqdn           = var.cluster_vip_fqdn != null ? var.cluster_vip_fqdn : ""
    cluster_api_internal_ip    = local.kubernetes_control_plane_endpoint_ip
    kube_api_endpoint          = module.azure_api_lb.api_lb_public_ip
    # cluster_lb_type            = var.cluster_lb_type
    cluster_lb_addresses       = local.loadbalancer_addresses != null ? local.loadbalancer_addresses : []
    nfs_ip                     = local.azure_nfs_ip
    jump_ip                    = local.azure_jump_ip
    jump_public_ip             = local.azure_jump_public_ip
    cr_ip                      = var.create_cr ? var.cr_ip : null
    system_ssh_keys_dir        = var.system_ssh_keys_dir
    azure_resource_group       = var.azure_resource_group
    azure_location             = var.azure_location
    node_labels                = local.node_labels
    node_taints                = local.node_taints
    ansible_user               = var.ansible_user != null ? var.ansible_user : ""
    ansible_password           = var.ansible_password != null ? var.ansible_password : ""
    # Subnet CIDRs for NFS exports (from azure_network module)
    aks_cidr_block             = module.azure_network.subnet_details["k8s"].address_prefixes[0]
    misc_cidr_block            = module.azure_network.subnet_details["misc"].address_prefixes[0]
    # Number of data disks expected (from nfs_data_disks tfvar)
    expected_disk_count        = var.create_nfs ? length(var.nfs_data_disks) : 0
  })
}

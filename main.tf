# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# vSphere – provider data sources
# =============================================================================

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Kubernetes - Node setup

## Control Plane Nodes
module "control_plane" {
  source = "./modules/vm"

  for_each = local.control_plane_nodes

  name             = replace(lower(each.key), "_", "-")
  datacenter_id    = data.vsphere_datacenter.dc.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
  instance_count   = length(each.value.ip_addresses) != 0 ? length(each.value.ip_addresses) : each.value.count
  num_cpu          = each.value.cpus
  memory           = each.value.memory
  disk_size        = each.value.os_disk
  misc_disks       = each.value.misc_disks
  ip_addresses     = length(each.value.ip_addresses) != 0 ? each.value.ip_addresses : []
}

## System Nodes
module "system" {
  source = "./modules/vm"

  for_each = local.system_nodes

  name             = replace(lower(each.key), "_", "-")
  datacenter_id    = data.vsphere_datacenter.dc.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
  instance_count   = length(each.value.ip_addresses) != 0 ? length(each.value.ip_addresses) : each.value.count
  num_cpu          = each.value.cpus
  memory           = each.value.memory
  disk_size        = each.value.os_disk
  misc_disks       = each.value.misc_disks
  ip_addresses     = length(each.value.ip_addresses) != 0 ? each.value.ip_addresses : []
}

## Nodes
module "node" {
  source = "./modules/vm"

  for_each = local.nodes

  name             = replace(lower(each.key), "_", "-")
  datacenter_id    = data.vsphere_datacenter.dc.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
  instance_count   = length(each.value.ip_addresses) != 0 ? length(each.value.ip_addresses) : each.value.count
  num_cpu          = each.value.cpus
  memory           = each.value.memory
  disk_size        = each.value.os_disk
  misc_disks       = each.value.misc_disks
  ip_addresses     = length(each.value.ip_addresses) != 0 ? each.value.ip_addresses : []
}

module "jump" {
  source = "./modules/vm"

  name             = "jump"
  instance_count   = var.create_jump ? 1 : 0
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  datacenter_id    = data.vsphere_datacenter.dc.id
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  ip_addresses     = [var.jump_ip]
  memory           = var.jump_memory
  num_cpu          = var.jump_num_cpu
  disk_size        = var.jump_disk_size
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
}

module "nfs" {
  source = "./modules/vm"

  name             = "nfs"
  instance_count   = var.create_nfs ? 1 : 0
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  datacenter_id    = data.vsphere_datacenter.dc.id
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  ip_addresses     = [var.nfs_ip]
  memory           = var.nfs_memory
  num_cpu          = var.nfs_num_cpu
  disk_size        = var.nfs_disk_size
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
}

module "cr" {
  source = "./modules/vm"

  name             = "cr"
  instance_count   = var.create_cr ? 1 : 0
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  datacenter_id    = data.vsphere_datacenter.dc.id
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  ip_addresses     = [var.cr_ip]
  memory           = var.cr_memory
  num_cpu          = var.cr_num_cpu
  disk_size        = var.cr_disk_size
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
}

module "postgresql" {
  source = "./modules/server"

  for_each = local.postgres_servers != null ? length(local.postgres_servers) != 0 ? local.postgres_servers : {} : {}

  name             = lower("${local.cluster_name}-${each.key}-pgsql")
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  datacenter_id    = data.vsphere_datacenter.dc.id
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  dns_servers      = var.dns_servers
  netmask          = var.netmask
  gateway          = var.gateway
  num_cpu          = each.value.server_num_cpu
  memory           = each.value.server_memory
  disk_size        = each.value.server_disk_size
  ip_address       = each.value.server_ip
}

# =============================================================================
# OpenStack – Kubernetes node modules
# =============================================================================

## Control Plane Nodes
module "os_control_plane" {
  source = "./modules/openstack-vm"

  for_each = var.deployment_type == "openstack" ? local.control_plane_nodes : {}

  name              = replace(lower(each.key), "_", "-")
  cluster_name      = local.cluster_name
  image_name        = var.openstack_image_name
  flavor_name       = lookup(each.value, "flavor", null) != null ? each.value.flavor : var.openstack_flavor_defaults
  keypair_name      = var.openstack_ssh_keypair
  security_groups   = var.openstack_security_groups
  network_name      = var.openstack_network_name
  floating_ip_pool  = var.openstack_floating_ip_pool
  availability_zone = var.openstack_availability_zone
  instance_count    = length(each.value.ip_addresses) != 0 ? length(each.value.ip_addresses) : each.value.count
  os_disk_size      = each.value.os_disk
  misc_disks        = each.value.misc_disks
  ip_addresses      = length(each.value.ip_addresses) != 0 ? each.value.ip_addresses : []
}

## System Nodes
module "os_system" {
  source = "./modules/openstack-vm"

  for_each = var.deployment_type == "openstack" ? local.system_nodes : {}

  name              = replace(lower(each.key), "_", "-")
  cluster_name      = local.cluster_name
  image_name        = var.openstack_image_name
  flavor_name       = lookup(each.value, "flavor", null) != null ? each.value.flavor : var.openstack_flavor_defaults
  keypair_name      = var.openstack_ssh_keypair
  security_groups   = var.openstack_security_groups
  network_name      = var.openstack_network_name
  floating_ip_pool  = var.openstack_floating_ip_pool
  availability_zone = var.openstack_availability_zone
  instance_count    = length(each.value.ip_addresses) != 0 ? length(each.value.ip_addresses) : each.value.count
  os_disk_size      = each.value.os_disk
  misc_disks        = each.value.misc_disks
  ip_addresses      = length(each.value.ip_addresses) != 0 ? each.value.ip_addresses : []
}

## Nodes
module "os_node" {
  source = "./modules/openstack-vm"

  for_each = var.deployment_type == "openstack" ? local.nodes : {}

  name              = replace(lower(each.key), "_", "-")
  cluster_name      = local.cluster_name
  image_name        = var.openstack_image_name
  flavor_name       = lookup(each.value, "flavor", null) != null ? each.value.flavor : var.openstack_flavor_defaults
  keypair_name      = var.openstack_ssh_keypair
  security_groups   = var.openstack_security_groups
  network_name      = var.openstack_network_name
  floating_ip_pool  = var.openstack_floating_ip_pool
  availability_zone = var.openstack_availability_zone
  instance_count    = length(each.value.ip_addresses) != 0 ? length(each.value.ip_addresses) : each.value.count
  os_disk_size      = each.value.os_disk
  misc_disks        = each.value.misc_disks
  ip_addresses      = length(each.value.ip_addresses) != 0 ? each.value.ip_addresses : []
}

## Jump Server
module "os_jump" {
  source = "./modules/openstack-vm"

  name              = "jump"
  cluster_name      = local.cluster_name
  image_name        = var.deployment_type == "openstack" ? var.openstack_image_name : "placeholder"
  flavor_name       = var.deployment_type == "openstack" ? var.openstack_flavor_defaults : "placeholder"
  keypair_name      = var.openstack_ssh_keypair
  security_groups   = var.openstack_security_groups
  network_name      = var.deployment_type == "openstack" ? var.openstack_network_name : "placeholder"
  floating_ip_pool  = var.openstack_floating_ip_pool
  availability_zone = var.openstack_availability_zone
  instance_count    = (var.deployment_type == "openstack" && var.create_jump) ? 1 : 0
  os_disk_size      = var.jump_disk_size
  ip_addresses      = var.jump_ip != null ? [var.jump_ip] : []
}

## NFS Server
module "os_nfs" {
  source = "./modules/openstack-vm"

  name              = "nfs"
  cluster_name      = local.cluster_name
  image_name        = var.deployment_type == "openstack" ? var.openstack_image_name : "placeholder"
  flavor_name       = var.deployment_type == "openstack" ? var.openstack_flavor_defaults : "placeholder"
  keypair_name      = var.openstack_ssh_keypair
  security_groups   = var.openstack_security_groups
  network_name      = var.deployment_type == "openstack" ? var.openstack_network_name : "placeholder"
  floating_ip_pool  = var.openstack_floating_ip_pool
  availability_zone = var.openstack_availability_zone
  instance_count    = (var.deployment_type == "openstack" && var.create_nfs) ? 1 : 0
  os_disk_size      = var.nfs_disk_size
  ip_addresses      = var.nfs_ip != null ? [var.nfs_ip] : []
}

## Container Registry Server
module "os_cr" {
  source = "./modules/openstack-vm"

  name              = "cr"
  cluster_name      = local.cluster_name
  image_name        = var.deployment_type == "openstack" ? var.openstack_image_name : "placeholder"
  flavor_name       = var.deployment_type == "openstack" ? var.openstack_flavor_defaults : "placeholder"
  keypair_name      = var.openstack_ssh_keypair
  security_groups   = var.openstack_security_groups
  network_name      = var.deployment_type == "openstack" ? var.openstack_network_name : "placeholder"
  floating_ip_pool  = var.openstack_floating_ip_pool
  availability_zone = var.openstack_availability_zone
  instance_count    = (var.deployment_type == "openstack" && var.create_cr) ? 1 : 0
  os_disk_size      = var.cr_disk_size
  ip_addresses      = var.cr_ip != null ? [var.cr_ip] : []
}

## PostgreSQL Servers
module "os_postgresql" {
  source = "./modules/openstack-vm"

  for_each = (var.deployment_type == "openstack" && local.postgres_servers != null) ? length(local.postgres_servers) != 0 ? local.postgres_servers : {} : {}

  name              = lower("${local.cluster_name}-${each.key}-pgsql")
  cluster_name      = local.cluster_name
  image_name        = var.openstack_image_name
  flavor_name       = var.openstack_flavor_defaults
  keypair_name      = var.openstack_ssh_keypair
  security_groups   = var.openstack_security_groups
  network_name      = var.openstack_network_name
  floating_ip_pool  = var.openstack_floating_ip_pool
  availability_zone = var.openstack_availability_zone
  instance_count    = 1
  os_disk_size      = each.value.server_disk_size
  ip_addresses      = each.value.server_ip != "" ? [each.value.server_ip] : []
}

## Azure – Kubernetes node modules (optional)
## Module usage is gated by `var.deployment_type == "azure"` so other flows are unchanged.

## Optional: create Azure VNet, subnets, and NSGs
module "az_network" {
  source = "./modules/azure_network"

  count = var.deployment_type == "azure" && var.azure_create_network ? 1 : 0

  prefix              = var.prefix
  resource_group_name = var.azure_resource_group
  location            = var.azure_location
  vnet_name           = null
  vnet_address_space  = var.azure_vnet_address_space
  dns_servers         = []
  subnets             = { for k, v in var.azure_subnets : k => { prefixes = v.prefixes, service_endpoints = [] } }
  existing_subnet_names = {}
  nsg_name            = null
  misc_nsg_name       = null
  create_nsg_rules    = true
  ssh_source_cidrs    = []
  api_server_source_cidrs = []
  nodeport_source_cidrs = []
  tags                = var.tags
}

## Control Plane Nodes
module "az_control_plane" {
  source = "./modules/azure_vm"

  for_each = var.deployment_type == "azure" ? local.control_plane_nodes : {}

  vm_name              = replace(lower(each.key), "_", "-")
  vm_size              = lookup(each.value, "vm_size", var.azure_default_vm_size)
  resource_group_name  = var.azure_resource_group
  azure_location       = var.azure_location
  subnet_id            = var.azure_create_network && length(module.az_network) > 0 ? lookup(module.az_network[0].subnet_ids, "k8s", var.azure_subnet_id) : var.azure_subnet_id
  nsg_id               = var.azure_create_network && length(module.az_network) > 0 ? module.az_network[0].nsg_id : var.azure_nsg_id
  create_nsg_association = true
  assign_public_ip     = var.azure_vm_public_ip_enabled
  admin_username       = var.azure_admin_username
  ssh_public_key       = var.ssh_public_key
  os_disk_size         = each.value.os_disk
  data_disk_sizes      = each.value.misc_disks
  node_labels          = each.value.node_labels
  node_taints          = each.value.node_taints
  tags                 = var.tags
}

## System Nodes
module "az_system" {
  source = "./modules/azure_vm"

  for_each = var.deployment_type == "azure" ? local.system_nodes : {}

  vm_name             = replace(lower(each.key), "_", "-")
  vm_size             = lookup(each.value, "vm_size", var.azure_default_vm_size)
  resource_group_name = var.azure_resource_group
  azure_location      = var.azure_location
  subnet_id           = var.azure_create_network && length(module.az_network) > 0 ? lookup(module.az_network[0].subnet_ids, "k8s", var.azure_subnet_id) : var.azure_subnet_id
  nsg_id              = var.azure_create_network && length(module.az_network) > 0 ? module.az_network[0].nsg_id : var.azure_nsg_id
  create_nsg_association = true
  assign_public_ip    = var.azure_vm_public_ip_enabled
  admin_username      = var.azure_admin_username
  ssh_public_key      = var.ssh_public_key
  os_disk_size        = each.value.os_disk
  data_disk_sizes     = each.value.misc_disks
  node_labels         = each.value.node_labels
  node_taints         = each.value.node_taints
  tags                = var.tags
}

## Nodes
module "az_node" {
  source = "./modules/azure_vm"

  for_each = var.deployment_type == "azure" ? local.nodes : {}

  vm_name             = replace(lower(each.key), "_", "-")
  vm_size             = lookup(each.value, "vm_size", var.azure_default_vm_size)
  resource_group_name = var.azure_resource_group
  azure_location      = var.azure_location
  subnet_id           = var.azure_create_network && length(module.az_network) > 0 ? lookup(module.az_network[0].subnet_ids, "k8s", var.azure_subnet_id) : var.azure_subnet_id
  nsg_id              = var.azure_create_network && length(module.az_network) > 0 ? module.az_network[0].nsg_id : var.azure_nsg_id
  create_nsg_association = true
  assign_public_ip    = var.azure_vm_public_ip_enabled
  admin_username      = var.azure_admin_username
  ssh_public_key      = var.ssh_public_key
  os_disk_size        = each.value.os_disk
  data_disk_sizes     = each.value.misc_disks
  node_labels         = each.value.node_labels
  node_taints         = each.value.node_taints
  tags                = var.tags
}

## Jump Server (optional)
module "az_jump" {
  source = "./modules/azure_vm"

  count = (var.deployment_type == "azure" && var.create_jump) ? 1 : 0

  vm_name             = "jump"
  vm_size             = var.azure_default_vm_size
  resource_group_name = var.azure_resource_group
  azure_location      = var.azure_location
  subnet_id           = var.azure_subnet_id
  nsg_id              = var.azure_nsg_id
  create_nsg_association = true
  assign_public_ip    = var.azure_vm_public_ip_enabled
  admin_username      = var.azure_admin_username
  ssh_public_key      = var.ssh_public_key
}

## NFS Server (optional)
module "az_nfs" {
  source = "./modules/azure_vm"

  count = (var.deployment_type == "azure" && var.create_nfs) ? 1 : 0

  vm_name             = "nfs"
  vm_size             = var.azure_default_vm_size
  resource_group_name = var.azure_resource_group
  azure_location      = var.azure_location
  subnet_id           = var.azure_subnet_id
  nsg_id              = var.azure_nsg_id
  create_nsg_association = true
  assign_public_ip    = var.azure_vm_public_ip_enabled
  admin_username      = var.azure_admin_username
  ssh_public_key      = var.ssh_public_key
}

## Container Registry (optional)
module "az_cr" {
  source = "./modules/azure_vm"

  count = (var.deployment_type == "azure" && var.create_cr) ? 1 : 0

  vm_name             = "cr"
  vm_size             = var.azure_default_vm_size
  resource_group_name = var.azure_resource_group
  azure_location      = var.azure_location
  subnet_id           = var.azure_subnet_id
  nsg_id              = var.azure_nsg_id
  create_nsg_association = true
  assign_public_ip    = var.azure_vm_public_ip_enabled
  admin_username      = var.azure_admin_username
  ssh_public_key      = var.ssh_public_key
}

## PostgreSQL Servers (optional)
module "az_postgresql" {
  source = "./modules/azure_vm"

  for_each = (var.deployment_type == "azure" && local.postgres_servers != null) ? length(local.postgres_servers) != 0 ? local.postgres_servers : {} : {}

  vm_name             = lower("${local.cluster_name}-${each.key}-pgsql")
  vm_size             = var.azure_default_vm_size
  resource_group_name = var.azure_resource_group
  azure_location      = var.azure_location
  subnet_id           = var.azure_subnet_id
  nsg_id              = var.azure_nsg_id
  create_nsg_association = true
  assign_public_ip    = var.azure_vm_public_ip_enabled
  admin_username      = var.azure_admin_username
  ssh_public_key      = var.ssh_public_key
}

## Optional: create API Load Balancer (public/internal)
module "az_api_lb" {
  source = "./modules/azure_api_lb"

  count = var.deployment_type == "azure" && var.azure_create_api_lb ? 1 : 0

  prefix              = var.prefix
  resource_group_name = var.azure_resource_group
  location            = var.azure_location
  control_plane_nic_ids = var.deployment_type == "azure" ? { for k, m in module.az_control_plane : k => m.network_interface_id } : {}
  create_public_ip    = true
  create_internal_lb  = true
  subnet_id           = var.azure_create_network && length(module.az_network) > 0 ? lookup(module.az_network[0].subnet_ids, "k8s", var.azure_subnet_id) : var.azure_subnet_id
  internal_lb_ip      = var.azure_api_internal_ip == null ? null : var.azure_api_internal_ip
  tags                = var.tags
}

# =============================================================================
# Ansible inventory + vars files (all deployment types)
# =============================================================================

resource "local_file" "inventory" {
  filename = var.inventory
  content = templatefile("${path.module}/templates/ansible/inventory.tmpl", {
    prefix            = replace(var.prefix, "-", "_")
    control_plane_ips = length(local.control_plane_ips) > 0 ? local.control_plane_ips : []
    node_ips          = length(local.node_ips) > 0 ? local.node_ips : []
    nfs_ip            = local.resolved_nfs_ip
    jump_ip           = local.resolved_jump_ip
    cr_ip             = local.resolved_cr_ip
    postgres_servers  = local.postgres_servers
    }
  )
}

resource "local_file" "ansible_vars" {
  filename = var.ansible_vars
  content = templatefile("${path.module}/templates/ansible/ansible-vars.yaml.tmpl", {
    ansible_user               = var.ansible_user
    ansible_password           = var.ansible_password
    deployment_type            = var.deployment_type
    iac_tooling                = var.iac_tooling
    prefix                     = var.prefix
    cluster_name               = local.cluster_name
    cluster_version            = var.cluster_version
    cluster_cni                = var.cluster_cni
    cluster_cni_version        = var.cluster_cni_version
    cluster_cri                = var.cluster_cri
    cluster_cri_version        = var.cluster_cri_version
    cluster_service_subnet     = var.cluster_service_subnet
    cluster_pod_subnet         = var.cluster_pod_subnet
    cluster_dns_ip             = local.cluster_dns_ip
    control_plane_ssh_key_name = var.control_plane_ssh_key_name
    cluster_vip_version        = var.cluster_vip_version
      cluster_vip_ip             = (var.deployment_type == "azure" && var.azure_create_api_lb && length(module.az_api_lb) > 0) ? module.az_api_lb[0].api_lb_frontend_ip : (var.cluster_vip_ip != null ? var.cluster_vip_ip : "")
    cluster_vip_fqdn           = var.cluster_vip_fqdn == null ? "${local.cluster_name}-vip.${var.cluster_domain}" : length(var.cluster_vip_fqdn) > 0 ? var.cluster_vip_fqdn : "${local.cluster_name}-vip.${var.cluster_domain}"
    cluster_lb_type            = var.cluster_lb_type
      cluster_lb_addresses       = (var.deployment_type == "azure" && var.azure_create_api_lb && length(module.az_api_lb) > 0) ? [module.az_api_lb[0].api_lb_frontend_ip] : local.loadbalancer_addresses
    nfs_ip                     = local.resolved_nfs_ip
    jump_ip                    = local.resolved_jump_ip
    cr_ip                      = local.resolved_cr_ip
    system_ssh_keys_dir        = var.system_ssh_keys_dir
    openstack_ssh_keypair      = var.openstack_ssh_keypair
    ssh_private_key_name       = var.control_plane_ssh_key_name
    azure_ccm_version          = var.azure_ccm_version
    azure_subscription_id      = var.azure_subscription_id
    azure_tenant_id            = var.azure_tenant_id
    azure_client_id            = var.azure_client_id
    azure_client_secret        = var.azure_client_secret
    azure_resource_group       = var.azure_resource_group
    azure_location             = var.azure_location
    azure_use_msi              = var.azure_use_msi
    vm_os                      = local.vm_os
    node_labels                = local.node_labels
    node_taints                = local.node_taints
    }
  )
}

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# vSphere — provider data sources
# =============================================================================

data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

# =============================================================================
# vSphere VM modules — Kubernetes nodes
# =============================================================================

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

## Worker / CAS / Generic Nodes
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

## Jump Server
module "jump" {
  source = "./modules/vm"
  count  = var.create_jump ? 1 : 0

  name             = "jump"
  instance_count   = 1
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
  num_cpu          = var.jump_num_cpu
  memory           = var.jump_memory
  disk_size        = var.jump_disk_size
  misc_disks       = []
  ip_addresses     = var.jump_ip != null ? [var.jump_ip] : []
}

## NFS Server
module "nfs" {
  source = "./modules/vm"
  count  = var.create_nfs ? 1 : 0

  name             = "nfs"
  instance_count   = 1
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
  num_cpu          = var.nfs_num_cpu
  memory           = var.nfs_memory
  disk_size        = var.nfs_disk_size
  misc_disks       = []
  ip_addresses     = var.nfs_ip != null ? [var.nfs_ip] : []
}

## Container Registry
module "cr" {
  source = "./modules/vm"
  count  = var.create_cr ? 1 : 0

  name             = "cr"
  instance_count   = 1
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
  num_cpu          = var.cr_num_cpu
  memory           = var.cr_memory
  disk_size        = var.cr_disk_size
  misc_disks       = []
  ip_addresses     = var.cr_ip != null ? [var.cr_ip] : []
}

## PostgreSQL Servers
module "postgresql" {
  source = "./modules/server"

  for_each = local.postgres_servers != null ? length(local.postgres_servers) != 0 ? local.postgres_servers : {} : {}

  name             = lower("${local.cluster_name}-${each.key}-pgsql")
  datacenter_id    = data.vsphere_datacenter.dc.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
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
# Ansible inventory + vars file generation
# =============================================================================

resource "local_file" "inventory" {
  filename = var.inventory
  content = templatefile("${path.module}/templates/inventory.tmpl", {
    prefix            = replace(var.prefix, "-", "_")
    control_plane_ips = length(local.control_plane_ips) > 0 ? local.control_plane_ips : []
    node_ips          = length(local.node_ips) > 0 ? local.node_ips : []
    nfs_ip            = local.resolved_nfs_ip
    jump_ip           = local.resolved_jump_ip
    cr_ip             = local.resolved_cr_ip
    postgres_servers  = local.postgres_servers
  })
}

resource "local_file" "ansible_vars" {
  filename = var.ansible_vars
  content = templatefile("${path.module}/templates/ansible-vars.yaml.tmpl", {
    ansible_user               = var.ansible_user != null ? var.ansible_user : ""
    ansible_password           = var.ansible_password != null ? var.ansible_password : ""
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
    cluster_vip_ip             = var.cluster_vip_ip != null ? var.cluster_vip_ip : ""
    cluster_vip_fqdn           = var.cluster_vip_fqdn == null ? (var.cluster_domain != null ? "${local.cluster_name}-vip.${var.cluster_domain}" : "") : (length(var.cluster_vip_fqdn) > 0 ? var.cluster_vip_fqdn : (var.cluster_domain != null ? "${local.cluster_name}-vip.${var.cluster_domain}" : ""))
    cluster_lb_type            = var.cluster_lb_type
    cluster_lb_addresses       = local.loadbalancer_addresses != null ? local.loadbalancer_addresses : []
    nfs_ip                     = local.resolved_nfs_ip
    jump_ip                    = local.resolved_jump_ip
    cr_ip                      = local.resolved_cr_ip
    system_ssh_keys_dir        = var.system_ssh_keys_dir
    vm_os                      = var.vm_os
    openstack_ssh_keypair      = ""
    node_labels                = local.node_labels
    node_taints                = local.node_taints
  })
}

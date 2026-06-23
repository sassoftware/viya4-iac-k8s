# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# Root dispatcher: selects the topology module based on deployment_type.
# To add a new deployment type (e.g. vsphere, bare_metal):
#   1. Create topologies/<name>/ with its own main.tf, variables.tf, outputs.tf, versions.tf
#   2. Add `is_<name> = local.deployment_type_normalized == "<name>"` in locals.tf
#   3. Add a new module block below with `count = local.is_<name> ? 1 : 0`
#   4. Add the deployment type to the validation in variables.tf
#   5. Wire outputs in outputs.tf using the same conditional pattern

module "azure" {
  count  = local.is_azure ? 1 : 0
  source = "./topologies/azure"

  deployment_type = var.deployment_type

  # Generic
  prefix              = var.prefix
  ansible_user        = var.ansible_user
  ansible_password    = var.ansible_password
  system_ssh_keys_dir = var.system_ssh_keys_dir
  inventory           = var.inventory
  ansible_vars        = var.ansible_vars
  tags                = var.tags
  iac_tooling         = var.iac_tooling

  # Azure Authentication
  azure_subscription_id = var.azure_subscription_id
  azure_tenant_id       = var.azure_tenant_id
  azure_client_id       = var.azure_client_id
  azure_client_secret   = var.azure_client_secret
  azure_use_msi         = var.azure_use_msi

  # Azure Resource Configuration
  azure_resource_group = var.azure_resource_group
  azure_location       = var.azure_location

  # Azure Networking
  azure_vnet_resource_group_name             = var.azure_vnet_resource_group_name
  azure_vnet_name                            = var.azure_vnet_name
  azure_vnet_address_space                   = var.azure_vnet_address_space
  azure_subnet_names                         = var.azure_subnet_names
  azure_subnets                              = var.azure_subnets
  azure_nsg_name                             = var.azure_nsg_name
  azure_misc_nsg_name                        = var.azure_misc_nsg_name
  azure_create_nsg_rules                     = var.azure_create_nsg_rules
  azure_default_public_access_cidrs          = var.azure_default_public_access_cidrs
  azure_vm_public_access_cidrs               = var.azure_vm_public_access_cidrs
  azure_cluster_endpoint_public_access_cidrs = var.azure_cluster_endpoint_public_access_cidrs
  azure_vm_public_ip_enabled                 = var.azure_vm_public_ip_enabled
  azure_accelerated_networking               = var.azure_accelerated_networking
  azure_use_custom_dns                       = var.azure_use_custom_dns
  azure_custom_dns_servers                   = var.azure_custom_dns_servers
  ssh_public_key                             = var.ssh_public_key

  # Kubernetes Cluster
  cluster_domain         = var.cluster_domain
  cluster_version        = var.cluster_version
  azure_ccm_version      = var.azure_ccm_version
  cluster_cni            = var.cluster_cni
  cluster_cni_version    = var.cluster_cni_version
  cluster_cri            = var.cluster_cri
  cluster_cri_version    = var.cluster_cri_version
  cluster_service_subnet = var.cluster_service_subnet
  cluster_pod_subnet     = var.cluster_pod_subnet
  cluster_vip_version    = var.cluster_vip_version
  cluster_vip_ip         = var.cluster_vip_ip
  cluster_vip_fqdn       = var.cluster_vip_fqdn
  cluster_lb_type        = var.cluster_lb_type
  cluster_lb_addresses   = var.cluster_lb_addresses

  # Node Pools
  node_pool_defaults         = var.node_pool_defaults
  node_pools                 = var.node_pools
  control_plane_ssh_key_name = var.control_plane_ssh_key_name

  # Jump Server
  create_jump       = var.create_jump
  jump_machine_type = var.jump_machine_type
  jump_os_disk      = var.jump_os_disk

  # NFS Server
  create_nfs       = var.create_nfs
  nfs_machine_type = var.nfs_machine_type
  nfs_os_disk      = var.nfs_os_disk
  nfs_data_disks   = var.nfs_data_disks

  # Container Registry
  create_cr = var.create_cr
  cr_ip     = var.cr_ip

  # Postgres
  postgres_server_defaults = var.postgres_server_defaults
  postgres_servers         = var.postgres_servers
}

module "openstack" {
  count  = local.is_openstack ? 1 : 0
  source = "./topologies/openstack"

  deployment_type = var.deployment_type

  # Generic
  prefix              = var.prefix
  ansible_user        = var.ansible_user
  ansible_password    = var.ansible_password
  system_ssh_keys_dir = var.system_ssh_keys_dir
  inventory           = var.inventory
  ansible_vars        = var.ansible_vars
  iac_tooling         = var.iac_tooling
  nat_ip              = var.nat_ip

  # OpenStack Provider
  openstack_auth_url          = var.openstack_auth_url
  openstack_user_name         = var.openstack_user_name
  openstack_password          = var.openstack_password
  openstack_tenant_name       = var.openstack_tenant_name
  openstack_domain_name       = var.openstack_domain_name
  openstack_region            = var.openstack_region
  openstack_network_name      = var.openstack_network_name
  openstack_floating_ip_pool  = var.openstack_floating_ip_pool
  openstack_image_name        = var.openstack_image_name
  openstack_ssh_keypair       = var.openstack_ssh_keypair
  openstack_security_groups   = var.openstack_security_groups
  openstack_availability_zone = var.openstack_availability_zone
  openstack_insecure          = var.openstack_insecure
  openstack_cacert_file       = var.openstack_cacert_file
  openstack_flavor_defaults   = var.openstack_flavor_defaults

  # Kubernetes Cluster
  cluster_domain             = var.cluster_domain
  cluster_version            = var.cluster_version
  cluster_cni                = var.cluster_cni
  cluster_cni_version        = var.cluster_cni_version
  cluster_cri                = var.cluster_cri
  cluster_cri_version        = var.cluster_cri_version
  cluster_service_subnet     = var.cluster_service_subnet
  cluster_pod_subnet         = var.cluster_pod_subnet
  cluster_vip_version        = var.cluster_vip_version
  cluster_vip_ip             = var.cluster_vip_ip
  cluster_vip_fqdn           = var.cluster_vip_fqdn
  cluster_lb_type            = var.cluster_lb_type
  cluster_lb_addresses       = var.cluster_lb_addresses
  control_plane_ssh_key_name = var.control_plane_ssh_key_name

  # Node Pools
  node_pool_defaults = var.node_pool_defaults
  node_pools         = var.node_pools

  # Jump Server
  create_jump    = var.create_jump
  jump_ip        = var.jump_ip
  jump_disk_size = var.jump_disk_size

  # NFS Server
  create_nfs    = var.create_nfs
  nfs_ip        = var.nfs_ip
  nfs_disk_size = var.nfs_disk_size

  # Container Registry
  create_cr    = var.create_cr
  cr_ip        = var.cr_ip
  cr_disk_size = var.cr_disk_size

  # Postgres
  postgres_server_defaults = var.postgres_server_defaults
  postgres_servers         = var.postgres_servers
}

module "bare_metal" {
  count  = local.is_bare_metal ? 1 : 0
  source = "./topologies/bare_metal"

  deployment_type = var.deployment_type

  # Generic
  prefix              = var.prefix
  ansible_user        = var.ansible_user
  ansible_password    = var.ansible_password
  system_ssh_keys_dir = var.system_ssh_keys_dir
  inventory           = var.inventory
  ansible_vars        = var.ansible_vars
  iac_tooling         = var.iac_tooling

  # VM / OS
  vm_os = var.vm_os

  # Kubernetes Cluster
  cluster_domain             = var.cluster_domain
  cluster_version            = var.cluster_version
  cluster_cni                = var.cluster_cni
  cluster_cni_version        = var.cluster_cni_version
  cluster_cri                = var.cluster_cri
  cluster_cri_version        = var.cluster_cri_version
  cluster_service_subnet     = var.cluster_service_subnet
  cluster_pod_subnet         = var.cluster_pod_subnet
  cluster_vip_version        = var.cluster_vip_version
  cluster_vip_ip             = var.cluster_vip_ip
  cluster_vip_fqdn           = var.cluster_vip_fqdn
  cluster_lb_type            = var.cluster_lb_type
  cluster_lb_addresses       = var.cluster_lb_addresses
  control_plane_ssh_key_name = var.control_plane_ssh_key_name

  # Node Pools
  node_pool_defaults = var.node_pool_defaults
  node_pools         = var.node_pools

  # Jump Server
  create_jump = var.create_jump
  jump_ip     = var.jump_ip

  # NFS Server
  create_nfs = var.create_nfs
  nfs_ip     = var.nfs_ip

  # Container Registry
  create_cr = var.create_cr
  cr_ip     = var.cr_ip

  # Postgres
  postgres_server_defaults = var.postgres_server_defaults
  postgres_servers         = var.postgres_servers
}

module "vsphere" {
  count  = local.is_vsphere ? 1 : 0
  source = "./topologies/vsphere"

  deployment_type = var.deployment_type

  # Generic
  prefix              = var.prefix
  ansible_user        = var.ansible_user
  ansible_password    = var.ansible_password
  system_ssh_keys_dir = var.system_ssh_keys_dir
  inventory           = var.inventory
  ansible_vars        = var.ansible_vars
  iac_tooling         = var.iac_tooling

  # VM / OS
  vm_os = var.vm_os

  # vSphere Connection
  vsphere_server        = var.vsphere_server
  vsphere_user          = var.vsphere_user
  vsphere_password      = var.vsphere_password
  vsphere_datacenter    = var.vsphere_datacenter
  vsphere_datastore     = var.vsphere_datastore
  vsphere_resource_pool = var.vsphere_resource_pool
  vsphere_folder        = var.vsphere_folder
  vsphere_template      = var.vsphere_template
  vsphere_network       = var.vsphere_network
  vsphere_allow_unverified_ssl = var.vsphere_allow_unverified_ssl

  # Network (static IPs)
  gateway     = var.gateway
  netmask     = var.netmask
  dns_servers = var.dns_servers

  # Kubernetes Cluster
  cluster_domain             = var.cluster_domain
  cluster_version            = var.cluster_version
  cluster_cni                = var.cluster_cni
  cluster_cni_version        = var.cluster_cni_version
  cluster_cri                = var.cluster_cri
  cluster_cri_version        = var.cluster_cri_version
  cluster_service_subnet     = var.cluster_service_subnet
  cluster_pod_subnet         = var.cluster_pod_subnet
  cluster_vip_version        = var.cluster_vip_version
  cluster_vip_ip             = var.cluster_vip_ip
  cluster_vip_fqdn           = var.cluster_vip_fqdn
  cluster_lb_type            = var.cluster_lb_type
  cluster_lb_addresses       = var.cluster_lb_addresses
  control_plane_ssh_key_name = var.control_plane_ssh_key_name

  # Node Pools
  node_pool_defaults = var.node_pool_defaults
  node_pools         = var.node_pools

  # Jump Server
  create_jump    = var.create_jump
  jump_ip        = var.jump_ip
  jump_num_cpu   = var.jump_num_cpu
  jump_memory    = var.jump_memory
  jump_disk_size = var.jump_disk_size

  # NFS Server
  create_nfs    = var.create_nfs
  nfs_ip        = var.nfs_ip
  nfs_num_cpu   = var.nfs_num_cpu
  nfs_memory    = var.nfs_memory
  nfs_disk_size = var.nfs_disk_size

  # Container Registry
  create_cr    = var.create_cr
  cr_ip        = var.cr_ip
  cr_num_cpu   = var.cr_num_cpu
  cr_memory    = var.cr_memory
  cr_disk_size = var.cr_disk_size

  # Postgres
  postgres_server_defaults = var.postgres_server_defaults
  postgres_servers         = var.postgres_servers
}

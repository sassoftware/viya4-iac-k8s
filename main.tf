data "vsphere_datacenter" "dc" {
  name = var.vsphere_datacenter
}

data "vsphere_resource_pool" "pool" {
  name          = var.vsphere_resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

module "control_plane" {
  source = "./modules/vm"

  name             = "control-plane" # Must use a - and not a _ or hostname will fail
  instance_count   = local.control_plane_count
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  datacenter_id    = data.vsphere_datacenter.dc.id
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  ip_addresses     = var.control_plane_ips
  memory           = var.control_plane_ram
  num_cpu          = var.control_plane_num_cpu
  disk_size        = var.control_plane_disk_size
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
}

module "node" {
  source = "./modules/vm"

  name             = "node"
  instance_count   = local.node_count
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = var.vsphere_folder
  datastore        = var.vsphere_datastore
  network          = var.vsphere_network
  datacenter_id    = data.vsphere_datacenter.dc.id
  template         = var.vsphere_template
  cluster_domain   = var.cluster_domain
  cluster_name     = local.cluster_name
  ip_addresses     = var.node_ips
  memory           = var.node_ram
  num_cpu          = var.node_num_cpu
  disk_size        = var.node_disk_size
  netmask          = var.netmask
  gateway          = var.gateway
  dns_servers      = var.dns_servers
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
  memory           = var.jump_ram
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
  memory           = var.nfs_ram
  num_cpu          = var.nfs_num_cpu
  disk_size        = var.nfs_disk_size
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
  cluster_name     = local.cluster_name
  dns_servers      = var.dns_servers
  netmask          = var.netmask
  gateway          = var.gateway
  num_cpu          = each.value.server_num_cpu
  memory           = each.value.server_ram
  disk_size        = each.value.server_disk_size
  ip_address       = each.value.server_ip
}

resource "local_file" "inventory" {
  filename = var.inventory
  content = templatefile("${path.module}/templates/ansible/inventory.tmpl", {
    prefix            = replace(var.prefix, "-", "_") # NOTE: Conversion needed in taking a URL value and using it as an Ansible Inventory value
    control_plane_ips = local.control_plane_count > 0 ? module.control_plane.ipaddresses : []
    node_ips          = local.node_count > 0 ? module.node.ipaddresses : []
    nfs_ip            = var.create_nfs ? var.nfs_ip : null
    jump_ip           = var.create_jump ? var.jump_ip : null
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
    cluster_name               = local.cluster_name
    cluster_version            = var.cluster_version
    cluster_cni                = var.cluster_cni
    cluster_cri                = var.cluster_cri
    cluster_service_subnet     = var.cluster_service_subnet
    cluster_pod_subnet         = var.cluster_pod_subnet
    control_plane_ssh_key_name = var.control_plane_ssh_key_name
    kube_vip_version           = var.kube_vip_version
    kube_vip_interface         = var.kube_vip_interface # NOTE: Cannot be a loopback interface. Must be the same on all machines
    kube_vip_ip                = var.kube_vip_ip
    kube_vip_dns               = var.kube_vip_dns == null ? "${local.cluster_name}-vip.${var.cluster_domain}" : length(var.kube_vip_dns) > 0 ? var.kube_vip_dns : "${local.cluster_name}-vip.${var.cluster_domain}"
    kube_vip_range             = var.kube_vip_range
    nfs_ip                     = var.create_nfs ? var.nfs_ip : null
    jump_ip                    = var.create_jump ? var.jump_ip : null
    system_ssh_keys_dir        = var.system_ssh_keys_dir
    }
  )
}

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = var.datacenter_id
}

data "vsphere_network" "network" {
  name          = var.network
  datacenter_id = var.datacenter_id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template
  datacenter_id = var.datacenter_id
}

locals {
  static_config = (length(var.ip_addresses) > 0 ? true : false)
  ip_addresses  = local.static_config ? var.ip_addresses : vsphere_virtual_machine.dhcp[*].default_ip_address
}

resource "vsphere_virtual_machine" "static" {
  count = (local.static_config ? var.instance_count : 0)

  name             = format("${var.cluster_name}-${var.name}-%02d", count.index + 1)
  resource_pool_id = var.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = var.num_cpu
  memory           = var.memory
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  folder           = var.folder
  enable_disk_uuid = "true"

  wait_for_guest_net_timeout  = "0"
  wait_for_guest_net_routable = "false"

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "os-disk-01"
    size             = var.disk_size
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
    unit_number      = 0
  }
  dynamic "disk" {
    for_each = var.misc_disks != null ? length(var.misc_disks) > 0 ? { for k, v in var.misc_disks : k => v } : {} : {}
    content {
      label            = format("misc-disk-%02d", disk.key + 1)
      size             = disk.value
      thin_provisioned = true
      unit_number      = disk.key + 1
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = format("${var.cluster_name}-${var.name}-%02d", count.index + 1)
        domain    = var.cluster_domain
      }

      network_interface {
        ipv4_address = var.ip_addresses[count.index]
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers

    }
  }
}

resource "vsphere_virtual_machine" "dhcp" {
  count = (local.static_config ? 0 : var.instance_count)

  name             = format("${var.cluster_name}-${var.name}-%02d", count.index + 1)
  resource_pool_id = var.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  num_cpus         = var.num_cpu
  memory           = var.memory
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  folder           = var.folder
  enable_disk_uuid = "true"

  #   wait_for_guest_net_timeout  = "0"
  #   wait_for_guest_net_routable = "false"

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "os-disk-01"
    size             = var.disk_size
    thin_provisioned = data.vsphere_virtual_machine.template.disks[0].thin_provisioned
    unit_number      = 0
  }
  dynamic "disk" {
    for_each = var.misc_disks != null ? length(var.misc_disks) > 0 ? { for k, v in var.misc_disks : k => v } : {} : {}
    content {
      label            = format("misc-disk-%02d", disk.key + 1)
      size             = disk.value
      thin_provisioned = true
      unit_number      = disk.key + 1
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = format("${var.cluster_name}-${var.name}-%02d", count.index + 1)
        domain    = var.cluster_domain
      }

      network_interface {}
    }
  }
}

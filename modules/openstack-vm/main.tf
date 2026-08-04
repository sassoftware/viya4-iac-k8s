# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_providers {
    openstack = {
      source = "terraform-provider-openstack/openstack"
    }
  }
}

locals {
  static_config = length(var.ip_addresses) > 0

  # Default cloud-init: create admin user with password 'admin' and enable SSH password auth.
  default_user_data = <<-EOF
    #cloud-config
    users:
      - default
      - name: admin
        groups: wheel
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        lock_passwd: false
    chpasswd:
      list: |
        admin:admin
      expire: false
    ssh_pwauth: true
    EOF

  user_data = var.user_data != null ? var.user_data : local.default_user_data

  # When floating IPs are enabled, expose the floating IP; otherwise the fixed IP.
  ip_addresses = [
    for idx in range(var.instance_count) :
    (var.floating_ip_pool != null
      ? openstack_networking_floatingip_v2.vm[idx].address
      : (local.static_config
        ? var.ip_addresses[idx]
        : openstack_compute_instance_v2.vm[idx].access_ip_v4
      )
    )
  ]
}

# -----------------------------------------------------------------------
# Glance image data source
# -----------------------------------------------------------------------
data "openstack_images_image_v2" "image" {
  name        = var.image_name
  most_recent = true
}

# -----------------------------------------------------------------------
# Nova flavor data source
# -----------------------------------------------------------------------
data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor_name
}

# -----------------------------------------------------------------------
# Neutron network data source
# -----------------------------------------------------------------------
data "openstack_networking_network_v2" "network" {
  name = var.network_name
}

# -----------------------------------------------------------------------
# Security group data sources — resolve names to UUIDs.
# openstack_networking_port_v2 requires UUIDs, not names.
# -----------------------------------------------------------------------
data "openstack_networking_secgroup_v2" "sg" {
  for_each = toset(var.security_groups)
  name     = each.value
}

# -----------------------------------------------------------------------
# Root / OS block-device volumes
# -----------------------------------------------------------------------
resource "openstack_blockstorage_volume_v3" "os_disk" {
  count       = var.instance_count
  name        = format("${var.cluster_name}-${var.name}-%02d-os-disk", count.index + 1)
  size        = var.os_disk_size
  image_id    = data.openstack_images_image_v2.image.id
  volume_type = null # use the default volume type; override if needed
}

# -----------------------------------------------------------------------
# Additional data volumes (misc_disks)
# -----------------------------------------------------------------------
resource "openstack_blockstorage_volume_v3" "misc_disk" {
  # Cartesian product: for each instance × each misc_disk
  count = var.instance_count * length(var.misc_disks)

  name = format(
    "${var.cluster_name}-${var.name}-%02d-misc-disk-%02d",
    floor(count.index / length(var.misc_disks)) + 1,
    count.index % length(var.misc_disks) + 1
  )
  size = var.misc_disks[count.index % length(var.misc_disks)]
}

# -----------------------------------------------------------------------
# Explicit Neutron ports — pre-created so we control static IPs and SGs.
# NOTE: allowed_address_pairs cannot be set at creation time under this
# environment's Neutron policy. The VIP pair is patched post-apply by
# oss-k8s.sh using the Neutron REST API (which allows PUT on existing ports).
# -----------------------------------------------------------------------
resource "openstack_networking_port_v2" "vm" {
  count              = var.instance_count
  name               = format("${var.cluster_name}-${var.name}-%02d-port", count.index + 1)
  network_id         = data.openstack_networking_network_v2.network.id
  security_group_ids = [for sg in data.openstack_networking_secgroup_v2.sg : sg.id]
  admin_state_up     = true

  # Static IP assignment when ip_addresses are provided; DHCP otherwise.
  dynamic "fixed_ip" {
    for_each = local.static_config ? [var.ip_addresses[count.index]] : []
    content {
      ip_address = fixed_ip.value
    }
  }
}

# -----------------------------------------------------------------------
# Nova compute instances
# -----------------------------------------------------------------------
resource "openstack_compute_instance_v2" "vm" {
  count             = var.instance_count
  name              = format("${var.cluster_name}-${var.name}-%02d", count.index + 1)
  flavor_id         = data.openstack_compute_flavor_v2.flavor.id
  key_pair          = var.keypair_name
  availability_zone = var.availability_zone

  # Boot from the pre-created root volume rather than an ephemeral disk
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.os_disk[count.index].id
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = 0
    delete_on_termination = true
  }

  # Attach misc data volumes
  dynamic "block_device" {
    for_each = length(var.misc_disks) > 0 ? { for i, v in var.misc_disks : i => v } : {}
    content {
      uuid                  = openstack_blockstorage_volume_v3.misc_disk[count.index * length(var.misc_disks) + block_device.key].id
      source_type           = "volume"
      destination_type      = "volume"
      boot_index            = -1
      delete_on_termination = true
    }
  }

  # Attach the pre-created port (carries allowed_address_pairs)
  network {
    port = openstack_networking_port_v2.vm[count.index].id
  }

  user_data = local.user_data

  metadata = {
    cluster_name = var.cluster_name
    role         = var.name
  }
}

# -----------------------------------------------------------------------
# Floating IPs (optional)
# -----------------------------------------------------------------------
resource "openstack_networking_floatingip_v2" "vm" {
  count = var.floating_ip_pool != null ? var.instance_count : 0
  pool  = var.floating_ip_pool
}

resource "openstack_networking_floatingip_associate_v2" "vm" {
  count       = var.floating_ip_pool != null ? var.instance_count : 0
  floating_ip = openstack_networking_floatingip_v2.vm[count.index].address
  port_id     = openstack_networking_port_v2.vm[count.index].id
}

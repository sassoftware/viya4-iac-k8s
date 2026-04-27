# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "cluster_name" {
  value = local.cluster_name
}

output "jump_admin_username" {
  value = var.ansible_user
}

output "jump_private_ip" {
  value = local.resolved_jump_ip
}

output "jump_public_ip" {
  value = local.resolved_jump_ip
}

# TODO: Fix this must be a variable
output "jump_rwx_filestore_path" {
  value = "/viya-share"
}

output "location" {
  value = "local"
}

output "nat_ip" {
  value = var.nat_ip
}

output "nfs_admin_username" {
  value = var.ansible_user
}

output "nfs_private_ip" {
  value = local.resolved_nfs_ip
}

output "nfs_public_ip" {
  value = local.resolved_nfs_ip
}

output "kube_config" {
  value = "${local.cluster_name}-kubeconfig.conf"
}

output "prefix" {
  value = var.prefix
}

output "provider" {
  value = "oss"
}

output "provder_account" {
  value = "oss"
}

output "rwx_filestore_endpoint" {
  value = local.resolved_nfs_ip
}

# TODO: Fix this must be a variable
output "rwx_filestore_path" {
  value = "/export"
}

output "postgres_servers" {
  value     = length(local.postgres_servers) != 0 ? local.postgres_outputs : null
  sensitive = true
}

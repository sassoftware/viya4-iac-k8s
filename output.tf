output "cluster_name" {
  value = local.cluster_name
}

output "cluster_node_pool_mode" {
  value = "default"
}

output "jump_admin_username" {
  value = "root"
}

output "jump_private_ip" {
  value = var.create_jump ? element(module.jump.ipaddresses, 0) : null
}

output "jump_public_ip" {
  value = var.create_jump ? element(module.jump.ipaddresses, 0) : null
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
  value = "root"
}

output "nfs_private_ip" {
  value = var.create_nfs ? element(module.nfs.ipaddresses, 0) : null
}

output "nfs_public_ip" {
  value = var.create_nfs ? element(module.nfs.ipaddresses, 0) : null
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
  value = var.create_nfs ? element(module.nfs.ipaddresses, 0) : null
}

# TODO: Fix this must be a variable
output "rwx_filestore_path" {
  value = "/export"
}

output "postgres_servers" {
  value     = length(local.postgres_servers) != 0 ? local.postgres_outputs : null
  sensitive = true
}

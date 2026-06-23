# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# =============================================================================
# Bare Metal — Ansible inventory + vars file generation
# =============================================================================
# No cloud VMs are provisioned. All node IPs are supplied statically via
# node_pools.ip_addresses in the tfvars file. Terraform only writes the two
# configuration files that oss-k8s.sh hands to Ansible.
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
    node_labels                = local.node_labels
    node_taints                = local.node_taints
  })
}

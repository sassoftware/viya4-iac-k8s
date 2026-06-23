# Description: This terraform test file checks the default values for variables in the variables.tf file.
#
# The test can be executed by running:
# terraform test --verbose --filter=tests/variable_defaults.tftest.hcl

variables {

  deployment_type  = "azure"
  ansible_user     = "ubuntu"
  ansible_password = "ubuntu"
  prefix           = "test-prefix"

  azure_resource_group = "test-resource-group"
  azure_location       = "eastus"

  system_ssh_keys_dir = "/workspace/.ssh"

  cluster_version        = "1.30.8"
  cluster_cri            = "containerd"
  cluster_cri_version    = "1.7.24"
  cluster_service_subnet = "10.43.0.0/16"
  cluster_pod_subnet     = "10.42.0.0/16"

  cluster_vip_version = "0.7.1"
  cluster_vip_ip      = "192.168.4.100"
  cluster_vip_fqdn    = "host.example.com"

  cluster_lb_type = "kube_vip"

  node_pools = {
    control_plane = {
      count        = 1
      machine_type = "Standard_D4s_v5"
      os_disk      = 100
      data_disks   = []
      node_taints  = ["node-role.kubernetes.io/control-plane:NoSchedule"]
      node_labels  = {}
    },
    system = {
      count        = 1
      machine_type = "Standard_D8s_v5"
      os_disk      = 100
      data_disks   = []
      node_taints  = []
      node_labels = {
        "kubernetes.azure.com/mode" = "system"
      }
    },
    generic = {
      count        = 1
      machine_type = "Standard_D16s_v5"
      os_disk      = 100
      data_disks   = [256]
      node_taints  = []
      node_labels = {
        "workload.sas.com/class" = "compute"
      }
    }
  }

  create_jump       = true
  jump_machine_type = "Standard_B2s"
  jump_os_disk      = 64

  create_nfs       = true
  nfs_machine_type = "Standard_D4s_v5"
  nfs_os_disk      = 100
  nfs_data_disks   = [256, 256, 256, 256]

}

run "cluster_cni_should_default_to_calico" {

  command = plan

  variables {}

  assert {
    condition     = var.cluster_cni == "calico"
    error_message = "A default value of \"${var.cluster_cni}\" for cluster_cni was not expected."
  }
}

run "cluster_cni_version_should_default_to_3_30_3" {

  command = plan

  variables {}

  assert {
    condition     = var.cluster_cni_version == "3.30.3"
    error_message = "A default value of \"${var.cluster_cni_version}\" for cluster_cni_version was not expected."
  }
}

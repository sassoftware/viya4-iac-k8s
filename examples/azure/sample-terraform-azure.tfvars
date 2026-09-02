# Sample terraform.tfvars for Azure deployment
# Copy this to terraform.tfvars and update values accordingly.

deployment_type = "azure"
prefix = "example-azure"

# Azure resource and location
azure_resource_group = "rg-example-azure"
azure_location       = "eastus"

# Subnet ID (full resource ID) where VMs will be created. Replace with your own.
azure_subnet_id = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-example-azure/providers/Microsoft.Network/virtualNetworks/example-vnet/subnets/k8s"
azure_nsg_id = "" # Optional: set to an existing NSG resource ID to use

# VM access
ssh_public_key = "~/.ssh/id_rsa.pub"
azure_vm_public_ip_enabled = false
control_plane_ssh_key_name = "cp_ssh"

# Optional per-cluster defaults
azure_default_vm_size = "Standard_DS2_v2"

# Node pools definition
node_pools = {
  control_plane = {
    count        = 3
    cpus         = 2
    memory       = 4096
    os_disk      = 50
    misc_disks   = []
    ip_addresses = []
    node_taints  = []
    node_labels  = {}
  }

  system = {
    count        = 1
    cpus         = 2
    memory       = 4096
    os_disk      = 50
    misc_disks   = []
    ip_addresses = []
    node_taints  = []
    node_labels  = {}
  }

  worker = {
    count        = 2
    cpus         = 4
    memory       = 8192
    os_disk      = 50
    misc_disks   = []
    ip_addresses = []
    node_taints  = []
    node_labels  = { "workload.sas.com/class" = "compute" }
    vm_size      = "Standard_DS2_v2"
  }
}

# Optional: let Terraform create networking and API LB resources for you.
# Disabled by default to avoid accidental network changes and charges.
azure_create_network = false
azure_create_api_lb = false

# =============================================================================
# vSphere provider defaults (placeholders for OpenStack-only deployment)
# =============================================================================
vsphere_server         = ""
vsphere_user           = ""
vsphere_password       = ""
vsphere_datacenter     = ""
vsphere_datastore      = ""
vsphere_resource_pool  = ""
vsphere_folder         = ""
vsphere_template       = ""
vsphere_network        = ""


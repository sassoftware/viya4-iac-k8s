# tflint-ignore: terraform_unused_declarations
variable "name" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "cluster_name" {
  type    = string
  default = null
}

variable "ip_addresses" {
  type    = list(string)
  default = []
}

variable "ip_address" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "instance_count" {
  type    = number
  default = 0
}

# tflint-ignore: terraform_unused_declarations
variable "datacenter_id" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "resource_pool_id" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "folder" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "datastore" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "network" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "template" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "cluster_domain" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "netmask" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "gateway" {
  type    = string
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "dns_servers" {
  type    = list(string)
  default = []
}

# tflint-ignore: terraform_unused_declarations
variable "num_cpu" {
  type    = number
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "memory" {
  type    = number
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "disk_size" {
  type    = number
  default = null
}

# tflint-ignore: terraform_unused_declarations
variable "misc_disks" {
  type    = list(number)
  default = []
}

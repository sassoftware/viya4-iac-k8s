terraform {
  required_version = ">= 1.0.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.1.1"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.2.2"
    }
  }
}

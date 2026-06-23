# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  deployment_type_normalized = lower(var.deployment_type)
  is_azure                   = local.deployment_type_normalized == "azure"
  is_openstack               = local.deployment_type_normalized == "openstack"
  is_bare_metal              = local.deployment_type_normalized == "bare_metal"
  is_vsphere                 = local.deployment_type_normalized == "vsphere"

  # active_module resolves the single instantiated topology module so that
  # outputs.tf can reference outputs uniformly as local.active_module.<output>
  # instead of repeating the four-way ternary chain for every output.
  # one() returns the sole element of a count=1 list, or null for count=0.
  active_module = (
    local.is_azure      ? one(module.azure)      :
    local.is_openstack  ? one(module.openstack)  :
    local.is_bare_metal ? one(module.bare_metal) :
    local.is_vsphere    ? one(module.vsphere)    : null
  )
}

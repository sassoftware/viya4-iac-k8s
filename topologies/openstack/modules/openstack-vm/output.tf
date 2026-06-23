# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "ip_addresses" {
  description = "List of IP addresses (floating if enabled, otherwise fixed/DHCP) for each instance."
  value       = local.ip_addresses
}

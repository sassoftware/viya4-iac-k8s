#!/usr/bin/env bash

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

all_disks=($(/usr/bin/lsblk --nodeps --noheadings --output NAME --paths | grep sd))
for disk in "${all_disks[@]}"; do
  partitions="$(/usr/bin/lsblk --noheadings --output PTTYPE "${disk}" | grep -vE "^$")"
  if [ "${partitions}" == "" ]; then
    fdisk ${disk} << EOF
n
p
1


w
EOF
  fi
done

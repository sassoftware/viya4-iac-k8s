#!/usr/bin/env bash

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

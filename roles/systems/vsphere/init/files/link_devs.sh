#!/usr/bin/env bash

# Find all disks not currently partitioned and add a partition for
all_disks=($(/usr/bin/lsblk --nodeps --noheadings --output NAME --paths | grep sd))
for disk in "${all_disks[@]}"; do
  partitions="$(/usr/bin/lsblk --noheadings --output PTTYPE "${disk}" | grep -vE "^$")"
  if [ "${partitions}" == "" ]; then
    # Capture the SERIAL number of the disk being used
    SERIAL_NUMBER=$(lsblk --noheadings --output SERIAL "${disk}" | grep -vE "^$" )
    if [[ "${disk}" =~ .*\/(.*)$ ]]; then
      RDISK="${BASH_REMATCH[1]}"
      if [ "${SERIAL_NUMBER}" != "" ]; then
        # Verifying the /mnt/sas/volumes directory is present
        if [[ ! -d /mnt/sas/volumes/ ]]; then
          mkdir -p /mnt/sas/volumes
        fi
        if [[ ! -L "/mnt/sas/volumes/sas-v4-${RDISK}-${SERIAL_NUMBER}" ]]; then
          ln -s "${disk}" "/mnt/sas/volumes/sas-v4-${RDISK}-${SERIAL_NUMBER}"
        fi
      fi
    fi
  fi
done

#!/usr/bin/env bash

# Copyright © 2022-2024, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

set -e

# setup container user
echo "viya4-iac-k8s:x:$(id -u):$(id -g)::/viya4-iac-k8s:/bin/bash" >> /etc/passwd
echo "viya4-iac-k8s:x:$(id -G | cut -d' ' -f 2):" >> /etc/group

exec /viya4-iac-k8s/oss-k8s.sh $@

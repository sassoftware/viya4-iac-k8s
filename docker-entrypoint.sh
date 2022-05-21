#!/usr/bin/env bash
set -e

# setup container user
echo "viya4-iac-k8s:x:$(id -u):$(id -g)::/viya4-iac-k8s:/bin/bash" >> /etc/passwd
echo "viya4-iac-k8s:x:$(id -G | cut -d' ' -f 2):" >> /etc/group

exec /viya4-iac-k8s/oss-k8s.sh $@

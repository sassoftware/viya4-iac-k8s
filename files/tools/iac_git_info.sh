#!/usr/bin/env bash

# Copyright © 2022-2023, SAS Institute Inc., Cary, NC, USA. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# We need to return an error if things don't work
set -e

if [[ -f $(which git) ]] && ( [[ -d "$(pwd)/.git" ]] || ( [[ -f "$(pwd)/.git" ]] && [[ $(cat "$(pwd)/.git" | grep "modules" ) ]] )) ; then
  git log -1 --format=format:'{ "git_hash": "%H" }'
else
  echo '{ "git_hash": "N/A" }'
fi

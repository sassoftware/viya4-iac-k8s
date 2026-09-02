Azure VM module

This module provides basic Azure VM resources used by the `oss-k8s` project.

It was imported from an external `azure-vm` helper project and may need further
integration with the top-level `main.tf` and variable naming used by this repo.

Usage: mirror the usage pattern of `modules/openstack-vm` in `main.tf` and
provide the necessary provider credentials and variables.

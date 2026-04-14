# SAS Viya 4 Infrastructure as Code (IaC) for Open Source Kubernetes

# Table of Contents

- [Kubernetes Support](#kubernetes-support)
- [Release Notes](#release-notes)
- [Overview](#overview)
- [Prerequisites](#prerequisites)
  - [Machines](#machines)
    - [VMware vSphere](#vmware-vsphere)
    - [Physical or Virtual Machines](#physical-or-virtual-machines)
  - [Networking](#networking)
  - [Technical Prerequisites](#technical-prerequisites)
    - [Script Requirements](#script-requirements)
    - [Docker Requirements](#docker-requirements)
- [Getting Started](#getting-started)
  - [Clone This Project](#clone-this-project)
  - [Customize Input Values](#customize-input-values)
    - [vSphere/vCenter Machines](#vspherevcenter-machines)
    - [SAS Viya IaC Configuration Files](#sas-viya-iac-configuration-files)
  - [Create and Manage Cluster Resources](#create-and-manage-cluster-resources)
- [Contributing](#contributing)
- [License](#license)
- [Additional Resources](#additional-resources)

## Kubernetes Support
At this time, the viya4-iac-k8s project supports Kubernetes versions 1.29 through 1.31. Support for Kubernetes 1.32 is to be determined.

## Release Notes

- A problem with the implementation of the default storage class and its usage of an NFS server as its
backing store has been addressed with [this issue](https://github.com/sassoftware/viya4-iac-k8s/issues/6).

## Overview

This project helps you to automate the cluster-provisioning phase of SAS Viya platform deployment. It contains Terraform scripts to provision cloud infrastructure resources for VMware, and it contains Ansible files to apply the elements of a Kubernetes cluster that are required to deploy SAS Viya 4 product offerings. Here is a list of resources that this project can create:

>- An open source [Kubernetes](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) cluster with the following components:
  >>- Container Runtime Interface (CRI): [containerd](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd)
  >>- Container Network Interface (CNI): [Calico](https://kubernetes.io/docs/concepts/cluster-administration/networking/#calico)
  >>- Cluster-level virtual IP address (VIP): [kube-vip](https://kube-vip.io/)
  >>- Cluster load balancer: [kube-vip](https://kube-vip.io/docs/usage/cloud-provider/) or [MetalLB](https://metallb.universe.tf/configuration/#layer-2-configuration)
>- Nodes with required labels and taints
>- Infrastructure to deploy the SAS Viya CAS server in SMP or MPP mode

[<img src="./docs/images/viya4-iac-k8s-diag.png" alt="Architecture Diagram" width="750"/>](./docs/images/viya4-iac-k8s-diag.png?raw=true)

To learn about all phases and options of the SAS Viya platform deployment process, see [Getting Started with SAS Viya and Open Source Kubernetes](https://documentation.sas.com/?cdcId=itopscdc&cdcVersion=default&docsetId=itopscon&docsetTarget=p1qungdpndaksyn156ng6duptma0.htm) in _SAS&reg; Viya&reg; Platform Operations_.

Once the resources are provisioned, use the [viya4-deployment](https://github.com/sassoftware/viya4-deployment) project to deploy SAS Viya platform in your cloud environment. For more information about SAS Viya platform requirements and documentation for the deployment process, refer to [SAS Viya Platform Operations](https://documentation.sas.com/?cdcId=itopscdc&cdcVersion=default&docsetId=itopswn&docsetTarget=titlepage.htm).

This project supports infrastructure that is built on **physical machines** ("bare metal" machines or Linux VMs) or on **VMware vSphere or vCenter** machines. If you need to create a cluster in [AWS](https://github.com/sassoftware/viya4-iac-aws), [Microsoft Azure](https://github.com/sassoftware/viya4-iac-azure/), or [GCP](https://github.com/sassoftware/viya4-iac-gcp/), use the appropriate SAS Viya IaC repository to perform the associated tasks.

## Prerequisites

Use of these tools requires operational knowledge of the following technologies:

- Systems
- Networking
- Bash
- [Terraform](https://www.terraform.io/intro/index.html)
- [Docker](https://www.docker.com/)
- [Ansible](https://docs.ansible.com/ansible/latest/user_guide/index.html#getting-started)
- [Helm](https://helm.sh/)
- [kube-vip](https://kube-vip.io/)
- [MetalLB](https://metallb.universe.tf/)
- [Kubernetes](https://kubernetes.io/docs/concepts/)

### Machines

The tools in this repository can create systems as needed **only** if you are running on VMware vSphere or vCenter. If you are not using vSphere or vCenter, you must supply your own machines (either VMs or physical machines).

Regardless of which method you choose, the machines in your deployment must meet the minimal requirements listed below:

- Machines in your target environment are running **Ubuntu Linux LTS 24.04** or **22.04**
- Machines have a default user account with password-less `sudo` capabilities
- At least 3 machines for the control plane nodes in your cluster
- At least 6 machines for the application nodes in your cluster
- 1 machine to serve as a jump server
- 1 machine to serve as an NFS server
- (Optional) At least 1 machine to host a PostgreSQL server (for the SAS Infrastructure Data Server component) if you plan to use an external database server with your cluster.

  You can instead use the internal PostgreSQL server, which is deployed by default on a node in the cluster.

> **NOTE**: Remember that these machines are not managed by a provider or by automated tooling. The nodes that you add here dictate the capacity of the cluster. If you need to increase or decrease the number of nodes in the cluster, you must perform the task manually. There is **NO AUTOSCALING** with this setup.

#### VMware vSphere

Deployment with vSphere requires a Linux image that can be used as the basis for your machines. This image requires the following minimal settings:

- Ubuntu Linux LTS 24.04 or 22.04 minimal installation
- 2 CPUs
- 4 GB of memory
- 8 GB disk, thin provisioned
- Root file system mounted at `/dev/sd2`

> **NOTE**: These items are all automatically adjusted to suit each individual deployment. These values are only the minimum starting point. They will be changed as components are created.

#### Physical or Virtual Machines

In addition to supporting VMware, this project also works with existing physical or virtual machines. You will need root access to these machines, and you will need to pass this along, following the sample [inventory](./examples/bare-metal/sample-inventory) and [ansible-vars.yaml](./examples/bare-metal/sample-ansible-vars.yaml) files that are provided in this repository.

### Networking

The following items are required to support the systems that are created in your environment:

- A network that is routable by all the target machines
- A static or assignable IP address for each target machine
- At least 3 floating IP addresses for the following components:
  - The Kubernetes cluster virtual IP address
  - The load balancer IP address
  - A CIDR block or range of IP addresses for additional load balancers. These are used when exposing user interfaces for various SAS product offerings.

A more comprehensive description of these items and their requirements can be found in the [Requirements](./docs/REQUIREMENTS.md) document.

### Technical Prerequisites

This project supports the following options for running the scripts in this repository to automate cluster provisioning:

- Running the bash `oss-k8s.sh` script on your local machine
- Using a Docker container to run the `oss-k8s.sh` script

   For more information, see [Docker Usage](./docs/user/DockerUsage.md). Using Docker to run the Terraform and Ansible scripts is recommended.

#### Script Requirements

View the [Dependencies Documentation](./docs/user/Dependencies.md) to see the required software that needs to installed in order to run the SAS Viya IaC tools here on your local system

#### Docker Requirements

If you are using the predefined dockerfile in this project in order to run the script, you need only an instance of [Docker](https://docs.docker.com/get-docker/).

## Getting Started

When you have prepared your environment with the prerequisites, you are ready to obtain and customize the Terraform scripts that will set up your Kubernetes cluster.

### Clone This Project

Run the following commands from a terminal session:

```bash
# clone this repo
git clone -b <release-version-tag> https://github.com/sassoftware/viya4-iac-k8s

# move to the project directory
cd viya4-iac-k8s
```
**NOTE:** To obtain a tagged release version of this project, always refer to the desired release version tag when cloning this repository as shown above. Alternatively, you can `git checkout <tag>` the tagged release version if you've already cloned the repository without a tag. 

You can find the latest release version in the [releases page](https://github.com/sassoftware/viya4-iac-k8s/releases).

### Customize Input Values

#### vSphere/vCenter Machines

Terraform scripts require variable definitions as input. Review the variables files and modify default values to meet your requirements. Create a file named `terraform.tfvars` in order to customize the input variable values that are documented in the [CONFIG-VARS.md](docs/CONFIG-VARS.md) file.

To get started, you can copy one of the example variable definition files that are provided in the `./examples` folder. For more information about the variables that are declared in each file, refer to the [CONFIG-VARS.md](docs/CONFIG-VARS.md) file.

You have the option to specify variable definitions that are not included in `terraform.tfvars` or to use a variable definition file other than `terraform.tfvars`. See [Advanced Terraform Usage](docs/user/AdvancedTerraformUsage.md) for more information.

#### SAS Viya IaC Configuration Files

In order to use this repository, modify the [inventory file](./examples/bare-metal/sample-inventory) to provide information about the machine targets for the SAS Viya platform deployment.

Modify the [ansible-vars.yaml file](./examples/bare-metal/sample-ansible-vars.yaml) to customize the configuration settings for your environment.

#### Worker Node Configuration (PSCLOUD-771)

The `viya4-iac-k8s` module supports fine-grained control over Kubernetes worker node configuration, including machine types, disk settings, scheduling constraints (taints), and pod affinity labels.

**Node Pool Types:**

The module supports four node pool types:

- **control_plane**: Kubernetes control plane (API server, etcd). 1 node for single-master, 3+ for HA.
- **system**: Kubernetes system components (DNS, kube-proxy, CNI, ingress). Typically 1-2 nodes.
- **cas**: (Optional) SAS Analytics Compute nodes. Memory-optimized machines for in-memory analytics.
- **generic**: General-purpose worker nodes for application workloads (programming, compute, storage).

**Configuration Variables:**

Each node pool type can be configured with:

- `machine_type`: Azure VM size (e.g., `Standard_D4s_v5`) or cloud provider equivalent
- `os_disk`: OS disk size in GB
- `data_disks`: List of data disk sizes in GB for attached storage
- `node_taints`: Kubernetes taints for scheduling constraints (list of `{key, value, effect}` objects)
- `node_labels`: Kubernetes labels for pod affinity and scheduling

**Usage Examples:**

Define node pools in `terraform.tfvars`:

```hcl
# Method 1: Complete node_pools definition with all details
node_pools = {
  control_plane = {
    count        = 1
    machine_type = "Standard_D4s_v5"
    os_disk      = 100
    data_disks   = []
    node_taints  = [
      {
        key    = "node-role.kubernetes.io/control-plane"
        value  = ""
        effect = "NoSchedule"
      }
    ]
    node_labels  = {
      "node-role.kubernetes.io/control-plane" = ""
    }
  }
  # ... additional node pools
}
```

Alternatively, use overrides for specific node types:

```hcl
# Method 2: Override specific node type configurations
control_plane_machine_type = "Standard_D4s_v5"
control_plane_labels = {
  "node-role.kubernetes.io/control-plane" = ""
  "cluster-role"                          = "master"
}

cas_node_machine_type = "Standard_E32s_v5"      # 32 vCPU, 256 GB
cas_node_data_disks   = [1024, 1024]             # 2x1TB for memory spill
cas_node_taints = [
  {
    key    = "workload/cas"
    value  = "true"
    effect = "NoSchedule"
  }
]
```

**Common Taint/Label Patterns:**

- **Control Plane**: `node-role.kubernetes.io/control-plane=:NoSchedule` (prevents user workloads)
- **System Nodes**: `CriticalAddonsOnly=true:NoSchedule` (for Kubernetes infrastructure)
- **CAS Nodes**: Custom taints like `workload/cas=true:NoSchedule` (isolates analytics workloads)
- **Pod Affinity**: Labels enable `nodeSelector` and `affinity` rules in pod specs

**Azure VM Size Reference:**

- D-series (General compute): D2s_v5 (2v/8GB) to D64s_v5 (64v/256GB)
- E-series (Memory-optimized): E4s_v5 (4v/32GB) to E80s_v5 (80v/504GB)

For more details, see the example configurations in `./examples/azure/sample-terraform-azure.tfvars`.

### Create and Manage Cluster Resources

Create and manage the required cluster resources for your SAS Viya 4 deployment. Perform one of the following steps, based on whether you are using Docker:

- Run the [oss-k8s.sh](docs/user/ScriptUsage.md) script directly on your workstation
- Start the [Docker container](docs/user/DockerUsage.md) (recommended)

## Contributing

> We welcome your contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to submit contributions to this project.

## License

> This project is licensed under the [Apache 2.0 License](LICENSE).

## Additional Resources

- [Terraform](https://www.terraform.io/)
- [Ansible](https://docs.ansible.com/ansible/2.9/index.html)
- [Docker](https://docs.docker.com/)
- [Helm](https://helm.sh/)
- [Kubernetes](https://kubernetes.io/)
  - [Kubernetes - Docs](https://kubernetes.io/docs/home/)
  - [Kubernetes - `kubeadm` Bootstrap guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
  - [Kubernetes - CRI - Containerd](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime)
  - [Kubernetes - CNI - Calico](https://kubernetes.io/docs/concepts/cluster-administration/networking/#calico)
- [kube-vip](https://kube-vip.io/)
- [MetalLB](https://metallb.universe.tf/)

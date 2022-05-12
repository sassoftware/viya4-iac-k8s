# SAS Viya 4 Infrastructure as Code (IaC) for Open Source (OSS) Kubernetes

## Overview

This project contains Terraform scripts to provision cloud infrastructure resources, when using vSphere, and Ansible to apply the needed elements of a kubernetes cluster that are required to deploy SAS Viya 4 product offerings. Here is a list of resources that this project can create:

>- Open Source (OSS) [Kubernetes](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) cluster with the following:
  >>- Container Runtime Interfaces : [contianerd](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd), [docker](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker), and [cri-o](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cri-o) [not ready]
  >>- Cluster Network Interfaces : [calico](https://kubernetes.io/docs/concepts/cluster-administration/networking/#calico)
  >>- Cluster Level Virtual IP (VIP) : [kube-vip](https://kube-vip.chipzoller.dev/)
  >>- Cloud Controller Manager : [kube-vip](https://kube-vip.chipzoller.dev/docs/usage/cloud-provider/)
>- Nodes with required labels taints
>- Infrastructure to deploy the SAS Viya CAS server in SMP or MPP mode

[<img src="./docs/images/viya4-iac-k8s-diag.png" alt="Architecture Diagram" width="750"/>](./docs/images/viya4-iac-k8s-diag.png?raw=true)

This project helps you to automate the cluster-provisioning phase of SAS Viya deployment. To learn about all phases and options of the SAS Viya deployment process, see [Getting Started with SAS Viya and Open Source (OSS) Kubernetes Service]() in _SAS&reg; Viya&reg; Operations_.

Once the resources are provisioned, use the [viya4-deployment](https://github.com/sassoftware/viya4-deployment) project to deploy SAS Viya 4 in your cloud environment. For more information about SAS Viya 4 requirements and documentation for the deployment process, refer to the [SAS&reg; Viya&reg; 4 IT Operations Guide](https://go.documentation.sas.com/doc/en/itopscdc/default/itopswlcm/home.htm).

This project focuses on infrastructure built on **bare-metal** and **vSphere/vCenter** systems. If you have a need to stand up a cluster in [AWS](https://github.com/sassoftware/viya4-iac-aws)/[Azure](https://github.com/sassoftware/viya4-iac-azure/)/[GCP](https://github.com/sassoftware/viya4-iac-gcp/) you'll use the appropriate IaC repo to perform that task.

## Prerequisites

Use of these tools requires operational knowledge of the following technologies:

- Systems
- Networking
- Bash
- Terraform
- Ansible
- Docker
- Helm
- kube-vip
- Kubernetes

### Systems

The code base can create systems as needed **only** if you have access to vSphere/vCenter by VMWare. If you are not using vSphere/vCenter, you can bring your own systems and/or VMs

Regardless of which method you choose, the systems must meet the minimal requirements listed below:

- Systems in your setup are using `Ubuntu 20.04 LTS`
- Systems in your setup have a default user with password-less `sudo` capabilities
- You have at least 3 systems for the control plane nodes in your cluster
- You have at least 6 systems for the compute nodes in your cluster
- You have 1 system for use as a jump server
- You have 1 system for use as a nfs server
- You have at least 1 system for use as a postgres server

**NOTE**: Remember these systems are not managed by a provider or automated tooling. The nodes you add here dictate the capacity of the cluster. If you need the cluster to nodes to increase or decrease that is something you have to do yourself. There is **NO AUTOSCALING** with this setup.

#### vSphere

For vSphere you will need an `Ubuntu 20.04 LTS` image that can be used as the basis for your systems. This image will need to have the following minimal settings:

- Ubuntu 20.04 LTS minimal installation
- 2 CPUs
- 4 GB memory
- 8 GB disk thin provisioned
- root filesystem mounted on /dev/sd2

**NOTE** These items are all adjusted to suit each individual system so these values are just the minimum starting point and will be changed as the systems are created.

#### Physical or Virtual Machines

This project also works with existing systems. You will need root access to these system and will need to pass this along following the sample [inventory](./examples/systems/inventory-bare-metal) and [ansible-vars.yaml](./examples/kubernetes/ansible-vars-oss.yaml) files provided in this repo.

### Networking

The following items are needed to support the systems created in your infrastructure

- The network must be routable by all systems
- A static or assignable IP for each system in your infrastructure
- At least 3 floating IPs set aside for
  - Your kubernetes cluster VIP
  - Your load balancer IP
  - A range of IPs used for extra load balancers used when exposing UIs for various SAS products

A more comprehensive document that outlines specifics on these items and their requirements can be found in this [Requirement](./docs/REQUIREMENTS.md) document.

### Technical Prerequisites

This project supports two options for running:

- Running the bash `run.sh` script on your local machine
- Using a Docker container to run the `run.sh` script (Docker is required)

For more information, see [Docker Usage](./docs/user/DockerUsage.md). Using Docker to run the Terraform/Ansible scripts is recommend.

#### Script Requirements

This section has links to tooling needed to run the tooling here on your local system. If you are using the Dockerfile you only need docker installed. That link is also included below

- [Terraform](https://www.terraform.io/downloads) - v.1.1.9
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) - v2.12.5
- [Docker](https://docs.docker.com/engine/install/) - v4.6.1
- [Helm](https://helm.sh/docs/intro/install/) - v3.8.2

#### Docker Requirements

- [Docker](https://docs.docker.com/get-docker/)

## Getting Started

When you have prepared your environment with the prerequisites, you are ready to obtain and customize the Terraform scripts that will set up your Kubernetes cluster.

### Clone this Project

Run the following commands from a terminal session:

```bash
# clone this repo
git clone https://github.com/sassoftware/viya4-iac-k8s

# move to the project directory
cd viya4-iac-k8s
```

### Customizing Input Values

#### vSphere/vCenter Systems

Terraform scripts require variable definitions as input. Review and modify default values to meet your requirements. Create a file named `terraform.tfvars` to customize any input variable value documented in the [CONFIG-VARS.md](docs/CONFIG-VARS.md) file.

To get started, you can copy one of the example variable definition files provided in the `./examples` folder. For more information about the variables that are declared in each file, refer to the [CONFIG-VARS.md](docs/CONFIG-VARS.md) file.

You have the option to specify variable definitions that are not included in `terraform.tfvars` or to use a variable definition file other than `terraform.tfvars`. See [Advanced Terraform Usage](docs/user/AdvancedTerraformUsage.md) for more information.

#### Provided systems

In order to use this repo you'll need to provide system information in the [`inventory` file](./examples/bare-metal/inventory) and configuration information in the [`ansible-vars.yaml` file](./examples/bare-metal/inventory). Links to those files has been provided here.

### Create and Manage Cluster resources

Create and manage the required cluster resources. Perform one of the following steps, based on whether your are using Docker:

- run [`run.sh`](docs/user/ScriptUsage.md) directly on your workstation
- run the [Docker container](docs/user/DockerUsage.md) (recommend)

## Contributing

> We welcome your contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to submit contributions to this project.

## License

> This project is licensed under the [Apache 2.0 License](LICENSE).

## Additional resources

- [Terraform](https://www.terraform.io/)
- [Ansible](https://docs.ansible.com/ansible/2.9/index.html)
- [Docker](https://docs.docker.com/)
- [Helm](https://helm.sh/)
- [Kubernetes](https://kubernetes.io/)
  - [Kubernetes - Docs](https://kubernetes.io/docs/home/)
  - [Kubernetes - `kubeadm` Bootstrap guide](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
  - [Kubernetes - CRI - Containerd](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime)
  - [Kubernetes - CNI - Calico](https://kubernetes.io/docs/concepts/cluster-administration/networking/#calico)
- [kube-vip](https://kube-vip.chipzoller.dev/)

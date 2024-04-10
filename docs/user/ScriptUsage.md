# Using the `oss-k8s.sh` Script

## Prerequisites

After satisfying all of the requirements that are listed in the [README file](../../README.md#script-requirements) for this repository, you are ready to begin.

### vSphere/vCenter Environment File for Authentication

Create a file that contains the authentication variable values to use at script invocation. Store the file outside of this repository, for example in  `$HOME/.vsphere_creds.env`. Protect that file with vSphere/vCenter credentials so that only you have Read access to it.

**NOTE**: Do not surround the values in the file with quotation marks, and make sure to avoid any trailing blank spaces.

Now each time you invoke the script, export the variables within the file to pass the credentials to it. You can run `export $(grep -v '^#' ~/.vsphere_creds.env | xargs)` to export them all at once.

An example of this file can be found in the `examples` directory [here](./../../examples/vsphere/.vsphere_creds.env).

### Bare Metal Environment File for Authentication

Create a file that contains the authentication variable values to use at script invocation. Store the file outside of this repository, for example in  `$HOME/.bare_metal_creds.env`. Protect that file with operating-system credentials so that only you have Read access to it

**NOTE**: Do not surround the values in the file with quotation marks, and make sure to avoid any trailing blank spaces.

Now each time you invoke the script, export the variables within the file to pass the credentials to it. You can run `export $(grep -v '^#' ~/.bare_metal_creds.env | xargs)` to export them all at once.

An example of this file can be found in the `examples` directory [here](./../../examples/bare-metal/.bare_metal_creds.env).

### Variable Definitions File (.tfvars)

Prepare your `terraform.tfvars` file, as described in [Customize Input Values](../../README.md#customize-input-values).

## Running the Configuration Script

This script offers options for both vSphere/vCenter and physical machines. Each section below describes what is needed for each option.

The script has the following options. These options include both actions for infrastructure and cluster creation along with encapsulated tooling.

```bash
Usage: ./oss-k8s.sh [apply|setup|install|update|uninstall|cleanup|destroy|helm|k|tf]

  Actions           - Items and Their Meanings

    apply           - IaC creation                     : vSphere/vCenter
    setup           - System and software setup        : systems
    install         - Kubernetes install               : systems
    update          - System and/or Kubernetes updates : systems
    uninstall       - Kubernetes uninstall             : systems
    cleanup         - Systems and software cleanup     : systems
    destroy         - IaC destruction                  : vSphere/vCenter

  Action groupings  - These items can be run together.
                      Alternate combinations are not allowed.

  creation items    - [apply setup install]
  update items      - [update]
  destruction items - [uninstall cleanup destroy]

  Toolset - Integrated tools

    helm            - Helm                             : Kubernetes
    k               - kubectl                          : Kubernetes
    tf              - Terraform                        : vSphere/vCenter
```

### Create Your Infrastructure and Kubernetes cluster - `vsphere`

To create your system resources, run the oss-k8s.sh script with the `apply setup install` command:

```bash
./oss-k8s.sh apply setup install
```

This command can take a few minutes to complete. Once complete, Terraform output values are written to the console. The `inventory` file, the `ansible-vars.yaml` and the `kubeconfig` file for the cluster stored here `[prefix]-oss-kubeconfig.conf` are written in the current directory, `$(pwd)`.

### Create Your Kubernetes Cluster Using Physical Machines - `bare_metal`

To create your Kubernetes cluster, run the oss-k8s.sh script with the `setup install` option:

```bash
./oss-k8s.sh setup install
```

### Display Terraform Outputs - `vSphere`

When your resources have been created using the `oss-k8s.sh` command, you can display Terraform output values by running the oss-k8s.sh script with the `tf` option:

```bash
./oss-k8s.sh tf output -state /workspace/terraform.tfstate
```

To display complex or hidden items in the output, pass those values to the `output` command:

```bash
./oss-k8s.sh tf output postgres_servers
```

**NOTE**: The `-state` flag is only optional if the `terraform.tfstate` file is not in the current directory.

### Tear Down Kubernetes Resources - vSphere/vCenter

To destroy all the resources that were created with the previous commands, run the using the oss-k8s.sh script `destroy` command.

```bash
./oss-k8s.sh destroy
```

**NOTE**: The 'destroy' action is irreversible.

## Interacting with the Kubernetes Cluster

Following the steps in [Running the Configuration Script](#running-the-configuration-script) writes the kube_config output value to a file, `./[prefix]-oss-kubeconfig.conf`. When the Kubernetes cluster is ready, use kubectl to interact with the cluster.

### Example Using kubectl

In order to run the `kubectl` command with the oss-k8s.sh script to list cluster nodes, be sure to set your `KUBECONFIG` environment variable so that it references the kubeconfig file that was created for your cluster. This example shows how you can get node information:

```bash
./oss-k8s.sh k get nodes -o wide
```

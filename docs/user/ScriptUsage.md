

### vSphere/vCenter

### Bring your own (BYO) systems

# Using the `oss-k8s.sh` Script

## Prerequisites

- After satisfying all of the perquisite items listed in the [README.md](../../README.md#script-requirements) doc for this repo you're ready to begin.

### vSphere/vCenter Environment File for Authentication

Create a file with the authentication variable values to use with container invocation. Store these values outside of this repo in a secure file, for example $HOME/.vsphere_creds.env. Protect that file with vSphere/vCenter credentials so only you have read access to it.

**NOTE**: Do not use quotes around the values in the file, and make sure to avoid any trailing blanks!

Now each time you invoke the container, specify the file with the --env-file option to pass on Azure credentials to the container.

An example of this file can be found in the `examples` directory [here](./../../examples/vsphere/.vsphere_creds.env).

### Bare Metal Environment File for Authentication

Create a file with the authentication variable values to use with container invocation. Store these values outside of this repo in a secure file, for example $HOME/.bare_metal_creds.env. Protect that file with bare-metal credentials so only you have read access to it

**NOTE**: Do not use quotes around the values in the file, and make sure to avoid any trailing blanks!

Now each time you invoke the container, specify the file with the --env-file option to pass on Azure credentials to the container.

An example of this file can be found in the `examples` directory [here](./../../examples/bare-metal/.bare_metal_creds.env).

### Variable Definitions (.tfvars) File

Prepare your `terraform.tfvars` file, as described in [Customize Input Values](../../README.md#customize-input-values).

## Running the configuration script

This script offers options for both vSphere/vCenter and bare-metal. Each section below describes what is needed for each option.

The script has the following options. These options include both actions for infrastructure and cluster creation along with encapsulated tooling.

```bash
Usage: ./oss-k8s.sh [apply|setup|install|update|uninstall|cleanup|destroy|helm|k|tf]

  Actions           - Items and there meanings

    apply           - IAC Creation                     : vSphere/vCenter
    setup           - System and software setup        : systems
    install         - Kubernetes install               : systems
    update          - System and/or Kubernetes updates : systems
    uninstall       - Kubernetes uninstall             : systems
    cleanup         - Systems and software cleanup     : systems
    destroy         - IAC Destruction                  : vSphere/vCenter

  Action groupings  - These items can be run together.
                      Alternate combinations are not allowed.

  creation items    - [apply setup install]
  update items      - [update]
  destruction items - [uninstall cleanup destroy]

  Tooling - Integrated tools

    helm            - Helm                             : kubernetes
    k               - kubectl                          : kubernetes
    tf              - Terraform                        : vSphere/vCenter
```

### Create your infrastructure and kubernetes cluster - `vsphere`

To create your system resources run the `oss-k8s.sh` script with the `apply setup install` commands:

```bash
./oss-k8s.sh apply setup install
```

This command can take a few minutes to complete. Once complete, Terraform output values are written to the console. The `inventory` file, the `ansible-vars.yaml` and the `kubeconfig` file for the cluster stored here `[prefix]-oss-kubeconfig.conf` are written in the current directory, `$(pwd)`.

### Create your kubernetes cluster using systems - `bare_metal`

To create your kubernetes cluster run the `oss-k8s.sh` script with the `setup install` options:

```bash
./oss-k8s.sh setup install
```

### Display Terraform Outputs - `vSphere`

Once your resources have been created using the `oss-k8s.sh` command, you can display Terraform output values by running the `oss-k8s.sh` script using the `tf` option:

```bash
./oss-k8s.sh tf output -state /workspace/terraform.tfstate
```

To display complex or hidden items in the output pass those values to the output command:

```bash
./oss-k8s.sh tf output postgres_servers
```

**NOTE**: The `-state` flag is only optional if the `terraform.tfstate` file is not in the current directory.

### Tear Down Kubernetes Resources - vSphere/vCenter

To destroy all the resources created with the previous commands, run the using the `oss-k8s.sh` script `destroy` command.

```bash
./oss-k8s.sh destroy
```

**NOTE**: The 'destroy' action is irreversible.

## Interacting With The Kubernetes cluster

[Creating the cloud resources](#running-the-configuration-script) writes the kube_config output value to a file ./[prefix]-oss-kubeconfig.conf. When the Kubernetes cluster is ready, use kubectl to interact with the cluster.

### Example Using kubectl

To run the kubectl command with the `oss-k8s.sh` script to list cluster nodes, be sure to set your `KUBECONFIG` environment variable so that it references the kube config file created for your cluster. This example shows how you can get node information:

```bash
./oss-k8s.sh k get nodes -o wide
```

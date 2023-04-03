# Using a Docker Container

## Prerequisites

After satisfying all of the prerequisite items that are listed in the [README.md](../../README.md#docker-requirements) file for this repository, you are ready to begin using the SAS Viya 4 IaC deployment tools for open source Kubernetes.

### Create the Docker Image

```bash
docker build -t viya4-iac-k8s .
```

The Docker image, `viya4-iac-k8s`, contains Ansible, Terraform, Helm, and kubectl executables. The entrypoint for the Docker image is `oss-k8s.sh`. The entrypoint is run with subcommands in the subsequent steps.

### VMware vSphere/vCenter Environment File for Authentication

Create a file with the authentication variable values to use with container invocation. Store these values outside of this repository in a secure file, such as `$HOME/.vsphere_creds.env`. Protect that file with vSphere/vCenter credentials so that only you have Read access to it.

> **NOTE**: Do not surround the values in the file with quotation marks, and make sure to avoid any trailing blank spaces.

Now each time that you invoke the container, specify the file with the `--env-file` option in order to pass login credentials to the container.

An example of this file can be found in the `examples` directory [here](./../../examples/vsphere/.vsphere_creds.env).

### Bare-Metal Environment File for Authentication

Create a file with the authentication variable values to use with container invocation. Store these values outside of this repo in a secure file, for example `$HOME/.bare_metal_creds.env`. Protect that file with bare-metal credentials so only you have read access to it.

> **NOTE**: Do not surround the values in the file with quotation marks, and make sure to avoid any trailing blank spaces.

Now each time you invoke the container, specify the file with the `--env-file` option to pass login credentials to the container.

An example of this file can be found in the `examples` directory [here](./../../examples/bare-metal/.bare_metal_creds.env).

### Docker Volume Mounts

Add volume mounts to the `docker run` command for all files and directories that must be accessible from inside the container:

| Volume | Description |
| :--- | :--- |
| `--volume=$(pwd):/workspace` | Where `$(pwd)` is used to store the terraform.tfvars file, the ansible-vars.yaml file, and the inventory file, and where the terraform.tfstate file, the inventory file, and the kubeconfig file will be written. |

To grant Docker permission to write to the local directory, use the [`--user` option](https://docs.docker.com/engine/reference/run/#user) and the `--group-add root` option.

> **NOTE:** Local references to `$HOME` (or "`~`") are mapped to the home directory in the container, `/viya4-iac-k8s`.

### Variable Definitions (.tfvars) File

Prepare your `terraform.tfvars` file, as described in [Customize Input Values](../../README.md#customize-input-values).

## Running the Configuration Script

This Docker image offers options for deployments in both vSphere/vCenter and on bare-metal machines (physical machines or VMs). This section describes the requirements for each option.

The encapsulated script supports the options that are described below. These options include actions for both infrastructure and cluster creation along with encapsulated tooling.

```bash
Usage: ./oss-k8s.sh [apply|setup|install|update|uninstall|cleanup|destroy|helm|k|tf]

  Actions           - Items and their meanings

    apply           - IaC creation                     : vSphere/vCenter
    setup           - Systems and software setup       : systems
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

  Tooling - Integrated tools

    helm            - Helm                             : Kubernetes
    k               - kubectl                          : Kubernetes
    tf              - Terraform                        : vSphere/vCenter
```

### Create Your Infrastructure and Kubernetes Cluster - `vsphere`

To create machine resources, run the `viya4-iac-k8s` Docker image with the `install` command and the `vsphere` option:

```bash
docker run --rm -it \
  --group-add root \
  --user $(id -u):$(id -g) \
  --env-file $HOME/.vsphere_docker_creds.env \
  --volume $(pwd):/workspace \
  viya4-iac-k8s apply setup install
```

This command can take a few minutes to complete. When it has completed, Terraform output values are written to the console. The inventory file, the ansible-vars.yaml file, and the kubeconfig file for the cluster, stored in the file [prefix]-oss-kubeconfig.conf, are written to the current directory, `$(pwd)`.

### Create Your Kubernetes Cluster Using Individual Machines - `bare_metal`

To create your Kubernetes cluster, run the viya4-iac-k8s Docker image with the `install` command and the `bare_metal` option:

```bash
docker run --rm -it \
  --group-add root \
  --user $(id -u):$(id -g) \
  --env-file $HOME/.bare_metal_docker_creds.env \
  --volume $(pwd):/workspace \
  viya4-iac-k8s setup install
```

### Display Terraform Outputs - vSphere/vCenter

Once your resources have been created using the `oss-k8s.sh` command, you can display Terraform output values by running the viya4-iac-k8s Docker image with the `output` command:

```bash
docker run --rm --group-add root \
  --user "$(id -u):$(id -g)" \
  --volume $(pwd):/workspace \
  viya4-iac-k8s \
  tf output -state /workspace/terraform.tfstate
```

To display complex or hidden items in the output, pass those values to the `output` command:

```bash
docker run --rm --group-add root \
  --user "$(id -u):$(id -g)" \
  --volume $(pwd):/workspace \
  viya4-iac-k8s \
  tf output postgres_servers
```

> **NOTE**: The `-state` flag is optional because the Docker image also adjusts for the tfstate file location.

### Tear Down Kubernetes Resources - vSphere/vCenter

To destroy all the resources that were created with the previous commands, run the Docker image viya4-iac-k8s with the `destroy` command.

```bash
docker run --rm -it \
  --group-add root \
  --user $(id -u):$(id -g) \
  --env-file $HOME/.vsphere_docker_creds.env \
  --volume $(pwd):/workspace \
  viya4-iac-k8s destroy
```

> **NOTE**: The `destroy` action is irreversible.

## Interacting with the Kubernetes Cluster

The act of [creating the cloud resources](#running-the-configuration-script) writes the `kube_config` output value to a file, `./[prefix]-oss-kubeconfig.conf`. When the Kubernetes cluster is ready, use kubectl to interact with the cluster.

### Example Using kubectl

Before you can run the kubectl command to list cluster nodes, be sure to mount your kubeconfig file variable so that it references the kubeconfig file that was created for your cluster. This example shows how you can get node information:

```bash
docker run --rm \
  --env=KUBECONFIG=/workspace/<your prefix>-oss-kubeconfig.conf \
  --volume=$(pwd):/workspace \
  viya4-iac-k8s k get nodes
```

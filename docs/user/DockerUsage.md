# Using a Docker Container

## Prerequisites

- After satisfying all of the perquisite items listed in the [README.md](../../README.md#docker-requirements) doc for this repo you're ready to begin.

### Create the Docker Image

```bash
docker build -t viya4-iac-k8s .
```

The Docker image, `viya4-iac-k8s`, contains Ansible, Terraform, Helm and kubectl executables. The entrypoint for the Docker image is `run.sh`. The entrypoint will be run with subcommands in the subsequent steps.

### vSphere/vCenter Environment File for Authentication

Create a file with the authentication variable values to use with container invocation. Store these values outside of this repo in a secure file, for example $HOME/.vsphere_creds.env. Protect that file with vSphere/vCenter credentials so only you have read access to it.

**NOTE**: Do not use quotes around the values in the file, and make sure to avoid any trailing blanks!

Now each time you invoke the container, specify the file with the --env-file option to pass on Azure credentials to the container.

An example of this file can be found in the `examples` directory [here](./../../examples/vsphere/.vsphere_creds.env).

### Bare Metal Environment File for Authentication

Create a file with the authentication variable values to use with container invocation. Store these values outside of this repo in a secure file, for example $HOME/.bare_metal_creds.env. Protect that file with bare-metal credentials so only you have read access to it.

**NOTE**: Do not use quotes around the values in the file, and make sure to avoid any trailing blanks!

Now each time you invoke the container, specify the file with the --env-file option to pass on Azure credentials to the container.

An example of this file can be found in the `examples` directory [here](./../../examples/bare-metal/.bare_metal_creds.enc).

### Docker Volume Mounts

Add volume mounts to the `docker run` command for all files and directories that must be accessible from inside the container:

| Volume | Description |
| :--- | :--- |
| `--volume=$(pwd):/workspace` | Where `$(pwd)` is used to store the `terraform.tfvars`, the `ansible-vars.yaml`, and the `inventory` files and where the `terraform.tfstate`, the `inventory` and the *kube config* file will be written. |

To grant Docker permission to write to the local directory, use the [`--user` option](https://docs.docker.com/engine/reference/run/#user) and the `--group-add root` option.

**NOTE:** Local references to `$HOME` (or "`~`") are mapped to the home directory `/viya4-iac-k8s` in the container.

### Variable Definitions (.tfvars) File

Prepare your `terraform.tfvars` file, as described in [Customize Input Values](../../README.md#customize-input-values).

## Running the configuration script

This docker image offers options for both vSphere/vCenter and bare-metal. Each section below describes what is needed for each option.

The encapsulated script as the following options. These options include both actions for infrastructure and cluster creation along with encapsulated tooling.

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

To create your system resources run the `viya4-iac-k8s` Docker image with the `install` command and the `vsphere` option:

```bash
docker run --rm -it \
  --group-add root \
  --user $(id -u):$(id -g) \
  --env-file $HOME/.vsphere_docker_creds.env \
  --volume $(pwd):/workspace \
  viya4-iac-k8s apply setup install
```

This command can take a few minutes to complete. Once complete, Terraform output values are written to the console. The `inventory` file, the `ansible-vars.yaml` and the `kubeconfig` file for the cluster, stored here `[prefix]-oss-kubeconfig.conf`, are written in the current directory, `$(pwd)`.

### Create your kubernetes cluster using systems - `bare_metal`

To create your kubernetes cluster run the `viya4-iac-k8s` Docker image with the `install` command and the `bare_metal` option:

```bash
docker run --rm -it \
  --group-add root \
  --user $(id -u):$(id -g) \
  --env-file $HOME/.bare_metal_docker_creds.env \
  --volume $(pwd):/workspace \
  viya4-iac-k8s setup install
```

### Display Terraform Outputs - `vSphere`

Once your resources have been created using the `run.sh` command, you can display Terraform output values by running the `viya4-iac-k8s` Docker image using the `output` command:

```bash
docker run --rm --group-add root \
  --user "$(id -u):$(id -g)" \
  --volume $(pwd):/workspace \
  viya4-iac-k8s \
  tf output -state /workspace/terraform.tfstate
```

To display complex or hidden items in the output pass those values to the output command:

```bash
docker run --rm --group-add root \
  --user "$(id -u):$(id -g)" \
  --volume $(pwd):/workspace \
  viya4-iac-k8s \
  tf output postgres_servers
```

**NOTE**: The `-state` flag is optional as the docker image also adjusts for the tfstate file location.

### Tear Down Kubernetes Resources - vSphere/vCenter

To destroy all the resources created with the previous commands, run the Docker image viya4-iac-k8s with the destroy command.

```bash
docker run --rm -it \
  --group-add root \
  --user $(id -u):$(id -g) \
  --env-file $HOME/.vsphere_docker_creds.env \
  --volume $(pwd):/workspace \
  viya4-iac-k8s destroy
```

**NOTE**: The 'destroy' action is irreversible.

## Interacting With The Kubernetes cluster

[Creating the cloud resources](#running-the-configuration-script) writes the kube_config output value to a file ./[prefix]-oss-kubeconfig.conf. When the Kubernetes cluster is ready, use kubectl to interact with the cluster.

### Example Using kubectl

To run the kubectl command to list cluster nodes, be sure to mount your kube config file variable so that it references the kube config file created for your cluster. This example shows how you can get node information:

```bash
docker run --rm \
  --env=KUBECONFIG=/workspace/<your prefix>-oss-kubeconfig.conf \
  --volume=$(pwd):/workspace \
  viya4-iac-k8s k get nodes
```

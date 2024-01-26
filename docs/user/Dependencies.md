# Dependency Versions

The following list details our dependencies and versions (~ indicates multiple possible sources):

| SOURCE         | NAME                 | VERSION     |
|----------------|----------------------|-------------|
| ~              | python               | >=3.10      |
| ~              | pip                  | >=22.0      |
| ~              | terraform            | >=1.4.5     |
| ~              | docker               | >=20.10.17  |
| ~              | helm                 | >=3         |
| ~              | kubectl              | 1.26 - 1.28 |
| ~              | git                  | any         |
| ~              | jq                   | >=1.6       |
| pip            | ansible              | 9.1.0       |
| pip            | openshift            | 0.13.1      |
| pip            | kubernetes           | 26.1.0      |
| pip            | dnspython            | 2.3.0       |
| pip            | jmespath             | 1.0.1       |
| ansible-galaxy | community.general    | 5.6.0       |
| ansible-galaxy | community.postgresql | 2.2.0       |
| ansible-galaxy | kubernetes.core      | 2.3.2       |
| ansible-galaxy | ansible.posix        | 1.4.0       |
| ansible-galaxy | ansible.utils        | 2.6.1       |

Python dependencies can be installed via `pip` using the `requirements.txt` provided in this project

```bash
pip install -r ./requirements.txt 
```
Ansible dependencies can be installed via `ansible-galaxy` using the `requirements.yaml` provided in this project.

```bash
ansible-galaxy install -r ./requirements.yaml
```

Required project dependencies are generally pinned to known working or stable versions to ensure users have a smooth initial experience. In some cases it may be required to change the default version of a dependency. In such cases users are welcome to experiment with alternate versions, however compatibility may not be guaranteed.

# Docker

If you are standing up your infrastructure via a Docker image created from the [Dockerfile](../../Dockerfile) overriding a dependency version can be accomplished by supplying one or more docker build arguments:

| ARG               | NOTE                              |
|-------------------|-----------------------------------|
| HELM_VERSION      | the version of helm to install    |
| KUBECTL_VERSION   | the version of kubectl to install |
| TERRAFORM_VERSION | the version terraform to install  |

Example of using build arguments to control specific versions of dependencies installed within the Docker image :
```bash
# Override kubectl version
docker build \
	--build-arg KUBECTL_VERSION=1.27.9 \
	-t viya4-iac-k8s .
```

# Install Script

If deploying via the [installation script](./ScriptUsage.md) you can modify the dependency requirements files for python and ansible respectively:

| FILE              | FOR                             |
|-------------------|---------------------------------|
| requirements.txt  | dependencies for python         |
| requirements.yaml | dependencies for ansible-galaxy |


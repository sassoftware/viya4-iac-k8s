# Base layer
FROM ubuntu:22.04 as baseline
RUN apt-get update && apt-get upgrade -y --no-install-recommends \
  && apt-get install -y python3 python3-dev python3-pip curl unzip gnupg --no-install-recommends \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
  && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Layers used for building/downloading/installing tools
FROM baseline as tool_builder
ARG HELM_VERSION=3.14.2
ARG KUBECTL_VERSION=1.28.7
ARG TERRAFORM_VERSION=1.7.4-*

WORKDIR /build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - \
  && echo "deb [arch=amd64] https://apt.releases.hashicorp.com focal main" > /etc/apt/sources.list.d/tf.list \
  && apt-get update \
  && curl -sLO https://storage.googleapis.com/kubernetes-release/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl && chmod 755 ./kubectl \
  && curl -ksLO https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 755 get-helm-3 \
  && ./get-helm-3 --version v$HELM_VERSION --no-sudo \
  && apt-get install -y terraform=$TERRAFORM_VERSION --no-install-recommends \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Installation steps
FROM baseline

RUN apt-get update && apt-get -y install git sshpass jq \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=tool_builder /usr/local/bin/helm /usr/local/bin/helm
COPY --from=tool_builder /build/kubectl /usr/local/bin/kubectl
COPY --from=tool_builder /usr/bin/terraform /usr/bin/terraform

WORKDIR /viya4-iac-k8s
COPY . /viya4-iac-k8s/

ENV HOME=/viya4-iac-k8s

RUN pip install -r ./requirements.txt --no-cache-dir \
  && ansible-galaxy install -r ./requirements.yaml \
  && chmod 755 /viya4-iac-k8s/docker-entrypoint.sh /viya4-iac-k8s/oss-k8s.sh \
  && terraform init \
  && chmod g=u -R /etc/passwd /etc/group /viya4-iac-k8s \
  && git config --system --add safe.directory /viya4-iac-k8s

ENV IAC_TOOLING=docker
ENV TF_VAR_iac_tooling=docker
ENV TF_VAR_inventory=/workspace/inventory
ENV TF_VAR_ansible_vars=/workspace/ansible-vars.yaml
ENV ANSIBLE_CONFIG=/viya4-iac-k8s/ansible.cfg

VOLUME ["/workspace"]
ENTRYPOINT ["/viya4-iac-k8s/docker-entrypoint.sh"]

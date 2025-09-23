# Base layer
FROM ubuntu:22.04 AS baseline

RUN apt-get update && apt-get upgrade -y --no-install-recommends \
  && apt-get install -y \
      python3 python3-dev python3-pip \
      curl unzip gnupg lsb-release ca-certificates software-properties-common \
      --no-install-recommends \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
  && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*


# Tool building layer
FROM baseline AS tool_builder

ARG HELM_VERSION=3.17.1
ARG KUBECTL_VERSION=1.32.7fix(ansible/docker): improve unattended-upgrades handling and Dockerfile tooling

ARG TERRAFORM_VERSION=1.10.5

WORKDIR /build
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install kubectl
RUN curl -sLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
  && chmod 755 ./kubectl

# Install helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get-helm-3 \
  && chmod 755 get-helm-3 \
  && ./get-helm-3 --version v${HELM_VERSION} --no-sudo

# Install terraform (APT + fallback to binary)
RUN set -e \
  && curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list \
  && apt-get update || true \
  && (apt-get install -y terraform=${TERRAFORM_VERSION} --no-install-recommends || \
      (echo "APT install failed. Falling back to direct download..." && \
       curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform.zip \
       && unzip terraform.zip \
       && mv terraform /usr/bin/terraform \
       && chmod +x /usr/bin/terraform \
       && rm terraform.zip)) \
  && apt-get clean && rm -rf /var/lib/apt/lists/*


# Final image with tools and dependencies
FROM baseline

# Install additional packages
RUN apt-get update && apt-get install -y \
      git sshpass jq \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy tools from builder stage
COPY --from=tool_builder /usr/local/bin/helm /usr/local/bin/helm
COPY --from=tool_builder /build/kubectl /usr/local/bin/kubectl
COPY --from=tool_builder /usr/bin/terraform /usr/bin/terraform

# Copy your source
WORKDIR /viya4-iac-k8s
COPY . /viya4-iac-k8s/

ENV HOME=/viya4-iac-k8s

RUN pip install -r ./requirements.txt --no-cache-dir \
  && ansible-galaxy install -r ./requirements.yaml \
  && chmod 755 /viya4-iac-k8s/docker-entrypoint.sh /viya4-iac-k8s/oss-k8s.sh \
  && terraform init \
  && git config --system --add safe.directory /viya4-iac-k8s \
  && chmod g=u -R /etc/passwd /etc/group /viya4-iac-k8s

ENV IAC_TOOLING=docker
ENV TF_VAR_iac_tooling=docker
ENV TF_VAR_inventory=/workspace/inventory
ENV TF_VAR_ansible_vars=/workspace/ansible-vars.yaml
ENV ANSIBLE_CONFIG=/viya4-iac-k8s/ansible.cfg

VOLUME ["/workspace"]
ENTRYPOINT ["/viya4-iac-k8s/docker-entrypoint.sh"]
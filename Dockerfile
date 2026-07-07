# -----------------------------------------------------------------------------
# Base Layer
# -----------------------------------------------------------------------------
FROM ubuntu:24.04 AS baseline

ENV DEBIAN_FRONTEND=noninteractive

# Force IPv4 only (optional)
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      unzip \
      gnupg \
      lsb-release \
      software-properties-common \
      python3 \
      python3-dev \
      python3-pip \
      python3-venv && \
    update-ca-certificates && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Python venv required for Ubuntu 24.04
RUN python3 -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"

# -----------------------------------------------------------------------------
# Tool Builder Layer
# -----------------------------------------------------------------------------
FROM baseline AS tool_builder

ARG HELM_VERSION=3.17.1
ARG KUBECTL_VERSION=1.34.6
ARG TERRAFORM_VERSION=1.10.5

WORKDIR /build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Kubectl
RUN curl -sLo kubectl \
    https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod +x kubectl

# Helm
RUN curl -fsSL \
    https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    -o get-helm-3 && \
    chmod +x get-helm-3 && \
    ./get-helm-3 --version v${HELM_VERSION} --no-sudo

# Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update || true && \
    (apt-get install -y terraform=${TERRAFORM_VERSION} || \
      (curl -fsSL \
         https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
         -o terraform.zip && \
       unzip terraform.zip && \
       mv terraform /usr/bin/terraform && \
       chmod +x /usr/bin/terraform && \
       rm -f terraform.zip)) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Final Runtime Image
# -----------------------------------------------------------------------------
FROM baseline

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      jq \
      sshpass \
      openssh-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy virtual environment
COPY --from=baseline /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"

# Copy tools
COPY --from=tool_builder /usr/local/bin/helm /usr/local/bin/helm
COPY --from=tool_builder /build/kubectl /usr/local/bin/kubectl
COPY --from=tool_builder /usr/bin/terraform /usr/bin/terraform

# Source
WORKDIR /viya4-iac-k8s

COPY . /viya4-iac-k8s/

ENV HOME=/viya4-iac-k8s

# Python requirements & Ansible
RUN pip install --upgrade pip setuptools && \
    pip install --no-cache-dir -r requirements.txt && \
    ansible-galaxy install -r requirements.yaml && \
    chmod 755 docker-entrypoint.sh oss-k8s.sh && \
    terraform init && \
    git config --system --add safe.directory /viya4-iac-k8s && \
    chmod g=u -R /etc/passwd /etc/group /viya4-iac-k8s

ENV IAC_TOOLING=docker
ENV TF_VAR_iac_tooling=docker
ENV TF_VAR_inventory=/workspace/inventory
ENV TF_VAR_ansible_vars=/workspace/ansible-vars.yaml
ENV ANSIBLE_CONFIG=/viya4-iac-k8s/ansible.cfg

VOLUME ["/workspace"]

ENTRYPOINT ["/viya4-iac-k8s/docker-entrypoint.sh"]


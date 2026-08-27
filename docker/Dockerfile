# Base layer
FROM ubuntu:24.04 AS baseline

RUN apt-get update && apt-get upgrade -y --no-install-recommends \
  && apt-get install -y \
      python3 python3-dev python3-pip python3-venv \
      curl unzip gnupg lsb-release ca-certificates software-properties-common \
      --no-install-recommends \
  && python3 -m venv /opt/venv \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
  && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PATH="/opt/venv/bin:$PATH"
ENV VIRTUAL_ENV="/opt/venv"


# Tool building layer
FROM baseline AS tool_builder

ARG HELM_VERSION=3.17.1
ARG KUBECTL_VERSION=1.35.6
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


# Final image
FROM baseline

RUN apt-get update && apt-get install -y \
      git sshpass jq \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=tool_builder /usr/local/bin/helm /usr/local/bin/helm
COPY --from=tool_builder /build/kubectl /usr/local/bin/kubectl
COPY --from=tool_builder /usr/bin/terraform /usr/bin/terraform

WORKDIR /viya4-iac-k8s
COPY . /viya4-iac-k8s/

ENV HOME=/viya4-iac-k8s

# Install Python dependencies and Ansible Galaxy collections.
# requirements.yml lives at repo root — single source of truth for all topologies.
# Pre-run terraform init so provider plugins are baked into the image.
RUN pip install --no-cache-dir --upgrade "pip==25.1.1" "setuptools==80.9.0" \
  && pip install -r ./requirements.txt --no-cache-dir \
  && ansible-galaxy collection install -r ./requirements.yml \
  && chmod 755 \
       /viya4-iac-k8s/docker/entrypoint.sh \
       /viya4-iac-k8s/scripts/deploy.sh \
       /viya4-iac-k8s/scripts/oss-k8s.sh \
  && terraform -chdir=/viya4-iac-k8s init \
  && git config --system --add safe.directory /viya4-iac-k8s \
  && chmod g=u -R /etc/passwd /etc/group /viya4-iac-k8s

ENV IAC_TOOLING=docker
ENV TF_VAR_iac_tooling=docker
ENV TF_VAR_inventory=/workspace/inventory
ENV TF_VAR_ansible_vars=/workspace/ansible-vars.yaml
# ANSIBLE_CONFIG is set dynamically by entrypoint.sh based on SYSTEM env var.
# Default to openstack for oss-k8s.sh usage; deploy.sh overrides for azure.

VOLUME ["/workspace"]
ENTRYPOINT ["/viya4-iac-k8s/docker/entrypoint.sh"]

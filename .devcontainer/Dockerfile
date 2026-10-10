FROM python:3.14-slim

WORKDIR /workspace

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/usr/lib/google-cloud-sdk/bin:${PATH}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      gcc \
      g++ \
      gnupg \
      make \
      musl-dev \
      openssl \
      unzip \
      zstd && \
    rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-input --break-system-packages --upgrade pip setuptools && \
    python -m pip install --no-input --break-system-packages dbt-core dbt-bigquery google-cloud-pubsub

RUN mkdir -p /usr/share/keyrings && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
      gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://apt.releases.hashicorp.com/gpg | \
      gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    . /etc/os-release && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" \
      > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      google-cloud-cli \
      terraform && \
    rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    case "$(dpkg --print-architecture)" in \
      amd64) K8S_ARCH=amd64 ;; \
      arm64) K8S_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"; \
    curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl"; \
    curl -fsSL -o /tmp/kubectl.sha256 "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${K8S_ARCH}/kubectl.sha256"; \
    echo "$(cat /tmp/kubectl.sha256)  /tmp/kubectl" | sha256sum --check --status; \
    install -m 0755 /tmp/kubectl /usr/local/bin/kubectl; \
    rm /tmp/kubectl /tmp/kubectl.sha256; \
    HELM_VERSION="$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest | grep -oE '"tag_name": *"[^"]+"' | head -n 1 | cut -d '"' -f 4)"; \
    test -n "${HELM_VERSION}"; \
    HELM_URL="https://get.helm.sh/helm-${HELM_VERSION}-linux-${K8S_ARCH}.tar.gz"; \
    test -n "${HELM_URL}"; \
    curl -fsSL "${HELM_URL}" -o /tmp/helm.tar.gz; \
    mkdir /tmp/helm; \
    tar -xzf /tmp/helm.tar.gz -C /tmp/helm; \
    install -m 0755 "/tmp/helm/linux-${K8S_ARCH}/helm" /usr/local/bin/helm; \
    rm -rf /tmp/helm /tmp/helm.tar.gz; \
    curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${K8S_ARCH}.tar.gz" | \
      tar -xz -C /usr/local/bin k9s

CMD ["/bin/bash"]

#TODO: przygotować pełne środowisko developerskie: Helm, opencode, git, gcloud, k9s, kubectl
FROM python:3.12.2-slim
WORKDIR /root

# Set environment variables
ENV PATH="/root/google-cloud-sdk/bin:${PATH}"
ENV DEBIAN_FRONTEND=noninteractive

# Install system packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
      curl \
      git \
      bash \
      gcc \
      musl-dev  \
      g++ \
      make \
      openssl \
      unzip \
      zstd \
      systemd \
#      gnupgp \
      software-properties-common \
      ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --no-input --break-system-packages --upgrade pip setuptools
RUN pip install --no-input --break-system-packages dbt-core dbt-bigquery

## Google Cloud SDK installation
RUN curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz &&\
    tar -xf google-cloud-cli-linux-x86_64.tar.gz -C /usr/local/bin &&\
    rm google-cloud-cli-linux-x86_64.tar.gz &&\
    cd /usr/local/bin/google-cloud-sdk &&\
    ./install.sh --quiet --usage-reporting=false --path-update=true --rc-path="/root/.bashrc" &&\
    ./bin/gcloud config set disable_usage_reporting true &&\
    ./bin/gcloud --quiet components update

RUN pip install --upgrade google-cloud-pubsub

## Terraform installation
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg &&\
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list &&\
    apt-get update &&\
    apt-get install -y terraform

# Default command
CMD ["/bin/bash"]
SHELL ["/bin/bash"]

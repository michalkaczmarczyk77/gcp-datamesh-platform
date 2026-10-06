# Extra providers this module needs beyond `google`, which the calling
# environment (infra/envs/<env>/providers.tf) already configures.
terraform {
  required_providers {
    random = { source = "hashicorp/random", version = "~> 3.6" }
    helm   = { source = "hashicorp/helm", version = "~> 2.14" }
  }
}

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.airflow.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.airflow.master_auth[0].cluster_ca_certificate)
  }
}

data "google_client_config" "default" {}

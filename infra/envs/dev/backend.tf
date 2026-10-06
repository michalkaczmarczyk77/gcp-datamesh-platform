terraform {
  required_version = ">= 1.9"
  backend "gcs" {
    bucket = "dtp-ref-tfstate"
    prefix = "envs/dev"
  }
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
    # Required by modules/airflow_gke (GKE Autopilot cluster + Helm release of Airflow).
    random = { source = "hashicorp/random", version = "~> 3.6" }
    helm   = { source = "hashicorp/helm", version = "~> 2.14" }
  }
}

# Appendix A — Cloud Composer as a managed drop-in alternative to
# modules/airflow_gke. Nothing else in the plan changes: dbt projects,
# domain.yaml contracts, Cosmos DAGs, and the Pub/Sub sync are all
# orchestrator-agnostic. DAG sync becomes `gcloud storage rsync` into
# `dag_gcs_prefix` (see README) instead of git-sync + Helm.

resource "google_service_account" "composer" {
  project      = var.project_id
  account_id   = "sa-composer-${var.env}"
  display_name = "Composer ${var.env} runtime"
}

resource "google_project_iam_member" "composer_worker" {
  for_each = toset([
    "roles/composer.worker",
    "roles/bigquery.jobUser",
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.composer.email}"
}

resource "google_composer_environment" "this" {
  name    = "dtp-${var.env}"
  project = var.project_id
  region  = var.region

  config {
    software_config {
      image_version = "composer-3-airflow-2.10.5-build.0"
      pypi_packages = {
        "astronomer-cosmos" = "==1.9.2"
        "dbt-bigquery"      = "==1.9.1"
        "dbt-core"          = "==1.9.3"
      }
      env_variables = {
        DBT_PROFILES_DIR           = "/home/airflow/gcs/dags/dbt_profiles"
        GCP_PROJECT                = var.project_id
        DTP_ENV                    = var.env
        AIRFLOW_VAR_DTP_BQ_LOCATION = var.location
      }
      airflow_config_overrides = {
        "core-dags_are_paused_at_creation"     = "True"
        "scheduler-min_file_process_interval" = "60"
      }
    }

    workloads_config {
      scheduler { cpu = 0.5, memory_gb = 2, storage_gb = 1, count = 1 }
      web_server { cpu = 0.5, memory_gb = 2, storage_gb = 1 }
      worker { cpu = 0.5, memory_gb = 2, storage_gb = 10, min_count = 1, max_count = 3 }
    }

    environment_size = "ENVIRONMENT_SIZE_SMALL"
    node_config { service_account = google_service_account.composer.email }
  }

  timeouts { create = "60m", update = "60m" }
}

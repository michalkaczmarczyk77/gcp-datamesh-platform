# Phase 3 / Step 3.4 — self-hosted Airflow on GKE Autopilot: cluster + a
# small Cloud SQL metadata DB + a Helm release of the official chart, wired
# through GKE Workload Identity (no keys anywhere).

resource "google_container_cluster" "airflow" {
  name                = "airflow-${var.env}"
  location            = var.region
  enable_autopilot    = true
  deletion_protection = false # weekend project: teardown must be one command
  ip_allocation_policy {}     # required for Autopilot (VPC-native)
}

resource "google_sql_database_instance" "airflow_meta" {
  name                = "airflow-meta-${var.env}"
  database_version    = "POSTGRES_15"
  region              = var.region
  deletion_protection = false
  settings {
    tier              = "db-f1-micro" # cheapest managed tier, fine for a demo
    availability_type = "ZONAL"
  }
}

resource "google_sql_database" "airflow" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow_meta.name
}

resource "random_password" "airflow_db" {
  length  = 24
  special = false
}

resource "google_sql_user" "airflow" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow_meta.name
  password = random_password.airflow_db.result
  #password = "MyS0LP@ssw0rT!"
}

resource "google_service_account" "airflow_gsa" {
  project    = var.project_id
  account_id = "sa-airflow-${var.env}"
}

resource "google_project_iam_member" "airflow_roles" {
  for_each = toset([
    "roles/bigquery.jobUser",
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/cloudsql.client",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.airflow_gsa.email}"
}

# Binds the in-cluster KSA to this GSA — GKE Workload Identity, no key ever leaves GCP.
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.airflow_gsa.name
  role                = "roles/iam.workloadIdentityUser"
  member              = "serviceAccount:${var.project_id}.svc.id.goog[airflow/airflow-scheduler]"
}

resource "google_service_account_iam_member" "cloud_sql_proxy_workload_identity" {
  service_account_id = google_service_account.airflow_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[airflow/cloud-sql-proxy]"
}

resource "helm_release" "airflow" {
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  #version          = "1.16.0" # Newest: 1.22.0 []; chart's own default Airflow image is 2.10.5 here - matches the Dockerfile below
  version          = "1.22.0" # Newest: 1.22.0 []; chart's own default Airflow image is 2.10.5 here - matches the Dockerfile below
  namespace        = "airflow"
  create_namespace = true
  values           = [file("${path.module}/../../../platform/helm/airflow/values-${var.env}.yaml")]

  set_sensitive {
    name  = "data.metadataConnection.pass"
    value = random_password.airflow_db.result
    #value = "MyS0LP@ssw0rT!"
  }

  depends_on = [google_container_cluster.airflow, google_sql_database.airflow, google_sql_user.airflow]
}

# Chart 1.20.0+ dropped support for Airflow versions below 2.11, so stay at
# 1.19.0 or lower while pinned to the 2.10.5 image; bump the Dockerfile's
# base image before moving past that chart version.

# One GSA per domain. Referenced by modules/bigquery_domain (dataset writer)
# and, in Phase 9's post-extraction shape, by that domain's own GKE Workload
# Identity binding once it runs its own Airflow/dbt image.

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = "sa-dtp-${var.domain}"
  display_name = "Data product domain SA — ${var.domain}"
}

resource "google_project_iam_member" "bq_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.this.email}"
}

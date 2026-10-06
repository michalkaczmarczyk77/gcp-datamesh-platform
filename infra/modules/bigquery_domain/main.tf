# Phase 3 / Step 3.2 — one dataset per (domain, layer); keeps naming and
# access uniform across every domain the platform onboards.

resource "google_bigquery_dataset" "this" {
  for_each    = toset(var.layers)
  dataset_id  = "${var.domain}_${each.value}"
  location    = var.location
  description = "Domain ${var.domain} — ${each.value} layer (${var.env})"

  delete_contents_on_destroy = var.env == "dev"

  labels = {
    domain     = var.domain
    layer      = each.value
    env        = var.env
    managed_by = "terraform"
  }

  # 90d retention on staging only; mart layers are kept indefinitely.
  default_partition_expiration_ms = each.value == "staging" ? 7776000000 : null
}

# Producer-owned write access; consumers only ever get reader on the mart layer.
resource "google_bigquery_dataset_iam_member" "domain_writer" {
  for_each   = google_bigquery_dataset.this
  dataset_id = each.value.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${var.domain_sa_email}"
}

resource "google_bigquery_dataset_iam_member" "consumers" {
  for_each   = toset(var.reader_members)
  dataset_id = google_bigquery_dataset.this["mart"].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

module "bigquery" {
  for_each        = local.domains
  source          = "../../modules/bigquery_domain"
  domain          = each.key
  env             = var.env
  location        = var.location
  domain_sa_email = module.domain_identity[each.key].sa_email
  reader_members = [for d, cfg in local.domains :
    "serviceAccount:${module.domain_identity[d].sa_email}"
    if contains([for c in try(cfg.consumes, []) : c.domain], each.key)
  ]
}

resource "google_bigquery_dataset" "dtp_platform" {
  dataset_id  = "dtp_platform"
  location    = var.location
  description = "Shared platform-level tables (event de-duplication, etc.) — not domain-owned."
  labels      = { managed_by = "terraform", purpose = "platform" }
}

resource "google_bigquery_table" "dtp_processed_events" {
  dataset_id          = google_bigquery_dataset.dtp_platform.dataset_id
  table_id            = "_dtp_processed_events"
  deletion_protection = false

  time_partitioning {
    type  = "DAY"
    field = "processed_at"
  }

  schema = jsonencode([
    { name = "event_id", type = "STRING", mode = "REQUIRED" },
    { name = "domain", type = "STRING", mode = "REQUIRED" },
    { name = "product", type = "STRING", mode = "REQUIRED" },
    { name = "logical_date", type = "STRING", mode = "REQUIRED" },
    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])
}

# Phase 3 / Step 3.5 — env composition. Everything is driven from
# domains/*/domain.yaml: adding a domain = adding a folder, no hand-wiring.

locals {
  domain_files = fileset("${path.module}/../../../domains", "*/domain.yaml")
  domains = { for f in local.domain_files :
    yamldecode(file("${path.module}/../../../domains/${f}")).domain =>
    yamldecode(file("${path.module}/../../../domains/${f}"))
  }

  products = flatten([for d, cfg in local.domains :
    [for p in cfg.produces : merge(p, { domain = d })]
  ])

  consumers_by_topic = { for t in distinct([for p in local.products : p.topic]) :
    t => [for d, cfg in local.domains :
      d if contains([for c in try(cfg.consumes, []) : c.topic], t)]
  }
}

module "domain_identity" {
  for_each   = local.domains
  source     = "../../modules/domain_identity"
  domain     = each.key
  project_id = var.project_id
}

#module "bigquery" {
#  for_each        = local.domains
#  source          = "../../modules/bigquery_domain"
#  domain          = each.key
#  env             = var.env
#  location        = var.location
#  domain_sa_email = module.domain_identity[each.key].sa_email
#  reader_members = [for d, cfg in local.domains :
#    "serviceAccount:${module.domain_identity[d].sa_email}"
#    if contains([for c in try(cfg.consumes, []) : c.domain], each.key)
#  ]
#}

#module "product_topic" {
#  for_each         = { for p in local.products : p.topic => p }
#  source           = "../../modules/data_product_topic"
#  project_id       = var.project_id
#  topic_name       = each.key
#  domain           = each.value.domain
#  product          = each.value.name
#  consumer_domains = lookup(local.consumers_by_topic, each.key, [])
#}

# This is the single most important structural move: the dependency graph
# between domains is declared in YAML and materialized as infrastructure,
# so nothing above is hand-wired.

module "airflow" {
  source     = "../../modules/airflow_gke"
  project_id = var.project_id
  env        = var.env
  region     = var.region
}

# --- Shared idempotency guard for cross-domain Pub/Sub consumers -----------
# Phase 5 / Step 5.5: dedups DataProductRelease events by event_id before a
# consumer DAG trusts one. Platform-level (not domain-owned), so it lives
# here rather than in modules/bigquery_domain. Read/written by
# platform/dags_common/freshness.py.

#resource "google_bigquery_dataset" "dtp_platform" {
#  dataset_id  = "dtp_platform"
#  location    = var.location
#  description = "Shared platform-level tables (event de-duplication, etc.) — not domain-owned."
#  labels      = { managed_by = "terraform", purpose = "platform" }
#}
#
#resource "google_bigquery_table" "dtp_processed_events" {
#  dataset_id          = google_bigquery_dataset.dtp_platform.dataset_id
#  table_id            = "_dtp_processed_events"
#  deletion_protection = false
#
#  time_partitioning {
#    type  = "DAY"
#    field = "processed_at"
#  }
#
#  schema = jsonencode([
#    { name = "event_id", type = "STRING", mode = "REQUIRED" },
#    { name = "domain", type = "STRING", mode = "REQUIRED" },
#    { name = "product", type = "STRING", mode = "REQUIRED" },
#    { name = "logical_date", type = "STRING", mode = "REQUIRED" },
#    { name = "processed_at", type = "TIMESTAMP", mode = "REQUIRED" },
#  ])
#}

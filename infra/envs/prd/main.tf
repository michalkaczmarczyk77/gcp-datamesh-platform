# Identical composition logic to infra/envs/dev/main.tf — same domains/*/domain.yaml
# manifests, same module wiring, just a different project/env via terraform.tfvars.

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

resource "google_pubsub_schema" "release_event" {
  name       = "data-product-release-v1"
  type       = "AVRO"
  definition = file("${path.module}/../../modules/data_product_topic/release_event.avsc")
}

module "product_topic" {
  for_each         = { for p in local.products : p.topic => p }
  source           = "../../modules/data_product_topic"
  project_id       = var.project_id
  topic_name       = each.key
  schema_id        = google_pubsub_schema.release_event.id
  domain           = each.value.domain
  product          = each.value.name
  consumer_domains = lookup(local.consumers_by_topic, each.key, [])
}

module "airflow" {
  source     = "../../modules/airflow_gke"
  project_id = var.project_id
  env        = var.env
  region     = var.region
}

# --- Shared idempotency guard for cross-domain Pub/Sub consumers -----------
# Phase 5 / Step 5.5: dedups DataProductRelease events by event_id before a
# consumer DAG trusts one. Read/written by platform/dags_common/freshness.py.

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

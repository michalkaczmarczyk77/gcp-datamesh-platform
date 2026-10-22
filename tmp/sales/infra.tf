# ---------------------------------------------------------------------------
# NOT part of infra/envs/{dev,prd}'s Terraform graph today.
#
# During the monorepo phase, this domain's infra (BigQuery datasets, its SA,
# its Pub/Sub topic/subscriptions) is provisioned centrally by the
# `domain.yaml` for-each loop in infra/envs/<env>/main.tf. Terraform only
# includes what a `module` block's `source` points at, so a stray .tf file
# here is inert unless something runs `terraform init` directly in this
# folder — which no documented workflow does.
#
# This file is what domains/sales/ becomes self-sufficient with after
# Phase 9's `git filter-repo` extraction into its own repo: a standalone
# root module with its own backend/provider config, calling the same
# shared modules (copied or published from the platform repo) that
# infra/envs/<env>/main.tf calls centrally today.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.9"
  # After extraction, point this at the domain's own state, e.g.:
  # backend "gcs" { bucket = "dtp-sales-tfstate", prefix = "envs/dev" }
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

variable "project_id" {
  type = string
}

variable "env" {
  type = string
}

variable "location" {
  type    = string
  default = "europe-central2"
}

module "identity" {
  source     = "../../infra/modules/domain_identity" # -> "./modules/domain_identity" post-extraction
  domain     = "sales"
  project_id = var.project_id
}

module "bigquery" {
  source          = "../../infra/modules/bigquery_domain"
  domain          = "sales"
  env             = var.env
  location        = var.location
  domain_sa_email = module.identity.sa_email
  reader_members  = [] # post-extraction: list the finance project's SA explicitly here
}

module "product_topic" {
  source           = "../../infra/modules/data_product_topic"
  project_id       = var.project_id
  topic_name       = "dtp.sales.fct_orders.released"
  domain           = "sales"
  product          = "fct_orders"
  consumer_domains = ["finance"] # post-extraction: a cross-project subscription, not a cross-domain for_each
}

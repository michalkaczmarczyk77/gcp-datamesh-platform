# ---------------------------------------------------------------------------
# NOT part of infra/envs/{dev,prd}'s Terraform graph today — see the header
# comment in domains/sales/infra.tf for the full explanation. This is what
# domains/finance/ becomes self-sufficient with after Phase 9 extraction.
#
# Note finance's *consumption* of sales.fct_orders needs no Terraform here:
# the subscription it reads from (dtp.sales.fct_orders.released.sub.finance)
# is created by sales' own product_topic module call, keyed off sales'
# `consumer_domains = ["finance"]`. Only the producer side manages topic/
# subscription infra.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.9"
  # After extraction, point this at the domain's own state, e.g.:
  # backend "gcs" { bucket = "dtp-finance-tfstate", prefix = "envs/dev" }
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
  source     = "../../infra/modules/domain_identity"
  domain     = "finance"
  project_id = var.project_id
}

module "bigquery" {
  source          = "../../infra/modules/bigquery_domain"
  domain          = "finance"
  env             = var.env
  location        = var.location
  domain_sa_email = module.identity.sa_email
  reader_members  = [] # no domain currently consumes finance's data products
}

module "product_topic" {
  source           = "../../infra/modules/data_product_topic"
  project_id       = var.project_id
  topic_name       = "dtp.finance.fct_revenue.released"
  domain           = "finance"
  product          = "fct_revenue"
  consumer_domains = [] # no downstream consumers yet
}

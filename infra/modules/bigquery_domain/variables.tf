variable "domain" {
  type        = string
  description = "Domain name, e.g. sales, finance."
}

variable "env" {
  type        = string
  description = "dev or prd."
}

variable "location" {
  type        = string
  description = "BigQuery dataset location, e.g. europe-central2."
}

variable "layers" {
  type    = list(string)
  default = ["staging", "mart"]
}

variable "domain_sa_email" {
  type        = string
  description = "Domain's own service account (from modules/domain_identity) — gets dataEditor on every layer."
}

variable "reader_members" {
  type        = list(string)
  default     = []
  description = "IAM members (e.g. serviceAccount:...) granted dataViewer on the mart layer only — other domains that consume this one's data products."
}

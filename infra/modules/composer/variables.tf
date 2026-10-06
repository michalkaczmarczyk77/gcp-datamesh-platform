variable "project_id" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-central2"
}

variable "location" {
  type        = string
  description = "BigQuery location, surfaced to DAGs as AIRFLOW_VAR_DTP_BQ_LOCATION."
  default     = "europe-central2"
}

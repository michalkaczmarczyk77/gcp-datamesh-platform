variable "project_id" {
  type        = string
  description = "dtp-ref-prd"
}

variable "env" {
  type    = string
  default = "prd"
}

variable "region" {
  type    = string
  default = "europe-central2"
}

variable "location" {
  type        = string
  description = "BigQuery dataset location."
  default     = "europe-central2"
}

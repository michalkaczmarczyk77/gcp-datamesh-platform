variable "project_id" {
  type        = string
  description = "GCP project that hosts the solution"
}

variable "env" {
  type    = string
  description = "Environment"
}

variable "region" {
  type    = string
  description = "Region"
}

variable "location" {
  type        = string
  description = "BigQuery dataset location."
}

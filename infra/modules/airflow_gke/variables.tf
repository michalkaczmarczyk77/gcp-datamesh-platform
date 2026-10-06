variable "project_id" {
  type = string
}

variable "env" {
  type        = string
  description = "dev or prd."
}

variable "region" {
  type    = string
  default = "europe-central2"
}

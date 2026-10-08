variable "state_bucket_name" {
  type        = string
  description = "Terraform state bucket name"
  #default     = "dtp-ref-tfstate"
}

variable "project_id" {
  type        = string
  description = "GCP project that hosts the WIF pool and CI service accounts"
  #default="dtp-ref-dev"
}

variable "region" {
  type    = string
  #default = "europe-central2"
}

#variable "state_bucket_name" {
#  type        = string
#  description = "Project State bucket name"
#  #default     = "michalkaczmarczyk77/gcp-datamesh-platform"
#}

variable "github_repo" {
  type        = string
  description = "GitHub org/repo allowed to assume the CI service accounts."
  #default     = "michalkaczmarczyk77/gcp-datamesh-platform"
}

variable "wif_pool" {
  type        = string
  description = "Workflow Identity Federation Pool Id"
  #default = dtp-github-pool
}

variable "wif_pool_github_provider" {
  type        = string
  description = "Workflow Identity Federation Github Provider Id"
  #default = dtp-github-provider
}

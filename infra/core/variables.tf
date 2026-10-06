variable "project_id" {
  type        = string
  description = "GCP project that hosts the WIF pool and CI service accounts (dtp-ref-dev, per Step 1.1)."
  default="dtp-ref-dev"
}

variable "region" {
  type    = string
  default = "europe-central2"
}

variable "github_repo" {
  type        = string
  description = "GitHub org/repo allowed to assume the CI service accounts."
  default     = "https://github.com/michalkaczmarczyk77/gcp-sandbox"
}

variable "state_bucket_name" {
  type        = string
  description = "Terraform state bucket name"
  default     = "dtp-ref-tfstate"
}

variable "kubeconfig_path" {
  type        = string
  default     = null
  description = "Optional kubeconfig path. Defaults to ~/.kube/config-microk8s-container.yaml and must point to a cluster endpoint reachable from this environment."
  nullable    = true
}

variable "kube_context" {
  type        = string
  default     = null
  description = "Optional kubeconfig context. Defaults to the current context."
  nullable    = true
}

variable "postgres_password" {
  type        = string
  sensitive   = true
  description = "Password for the local Airflow PostgreSQL user."

  validation {
    condition     = length(var.postgres_password) >= 8
    error_message = "postgres_password must be at least 16 characters long."
  }
}

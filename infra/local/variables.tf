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
  description = "Password for the local Airflow PostgreSQL user: at least 6 characters, using only letters, digits, and #$%_, with at least one uppercase letter, lowercase letter, digit, and allowed symbol."

  validation {
    condition = (
      length(var.postgres_password) >= 6 &&
      can(regex("^[A-Za-z0-9#$%_]+$", var.postgres_password)) &&
      can(regex("[A-Z]", var.postgres_password)) &&
      can(regex("[a-z]", var.postgres_password)) &&
      can(regex("[0-9]", var.postgres_password)) &&
      can(regex("[#$%_]", var.postgres_password))
    )
    error_message = "postgres_password must be at least 6 characters, contain only letters, digits, and #$%_, and include at least one uppercase letter, lowercase letter, digit, and allowed symbol."
  }
}

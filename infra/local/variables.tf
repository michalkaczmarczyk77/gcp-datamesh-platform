variable "kubeconfig_path" {
  type        = string
  default     = null
  description = "Optional kubeconfig path. Defaults to ~/.kube/microk8s-config."
  nullable    = true
}

variable "kube_context" {
  type        = string
  default     = null
  description = "Optional kubeconfig context. Defaults to the current context."
  nullable    = true
}

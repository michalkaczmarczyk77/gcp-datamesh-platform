terraform {
  required_version = ">= 1.9"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand(coalesce(var.kubeconfig_path, "~/.kube/config-microk8s-container.yaml"))
  config_context = var.kube_context
}

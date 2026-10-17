terraform {
  required_version = ">= 1.9"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path != null ? var.kubeconfig_path : pathexpand("~/.kube/microk8s-config")
    config_context = var.kube_context
  }
}

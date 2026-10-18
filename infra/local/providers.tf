terraform {
  required_version = ">= 1.9"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path    = pathexpand(coalesce(var.kubeconfig_path, "~/.kube/config-microk8s-container.yaml"))
    config_context = var.kube_context
  }
}

provider "kubernetes" {
  config_path    = pathexpand(coalesce(var.kubeconfig_path, "~/.kube/config-microk8s-container.yaml"))
  config_context = var.kube_context
}

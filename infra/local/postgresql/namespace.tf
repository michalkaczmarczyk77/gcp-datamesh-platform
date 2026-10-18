resource "kubernetes_namespace_v1" "postgresql" {
  metadata {
    name = "db-services"
  }
}
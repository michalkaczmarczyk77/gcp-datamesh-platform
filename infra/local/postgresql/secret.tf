resource "kubernetes_secret_v1" "postgresql" {
  metadata {
    name      = "airflow-postgresql"
    namespace = kubernetes_namespace_v1.postgresql.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = var.postgres_password
  }

  type = "Opaque"
}

resource "kubernetes_namespace_v1" "airflow" {
  metadata {
    name = "airflow"
  }
}

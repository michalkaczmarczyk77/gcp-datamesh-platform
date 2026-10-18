resource "helm_release" "airflow" {
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  version          = "1.22.0"
  namespace        = kubernetes_namespace_v1.airflow.metadata[0].name
  create_namespace = false
  values           = [file("${path.module}/../../platform/helm/airflow/values-local.yaml")]

  set_sensitive {
    name  = "data.metadataConnection.pass"
    value = var.postgres_password
  }

  depends_on = [
    kubernetes_deployment_v1.postgresql,
    kubernetes_service_v1.postgresql,
  ]

  timeout = 600
}

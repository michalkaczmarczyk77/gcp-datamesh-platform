resource "helm_release" "airflow" {
  name             = "airflow"
  repository       = "https://airflow.apache.org"
  chart            = "airflow"
  version          = "1.22.0"
  namespace        = "airflow"
  create_namespace = true
  values           = [file("${path.module}/../../platform/helm/airflow/values-local.yaml")]

  timeout = 600
}

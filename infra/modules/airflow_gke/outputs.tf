output "gke_cluster_name" {
  value = google_container_cluster.airflow.name
}

output "airflow_gsa_email" {
  value = google_service_account.airflow_gsa.email
}

output "cloudsql_connection_name" {
  value = "${var.project_id}:${var.region}:${google_sql_database_instance.airflow_meta.name}"
}

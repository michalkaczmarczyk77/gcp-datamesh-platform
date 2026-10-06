output "gke_cluster_name" {
  value = module.airflow.gke_cluster_name
}

output "airflow_gsa_email" {
  value = module.airflow.airflow_gsa_email
}

output "cloudsql_connection_name" {
  value = module.airflow.cloudsql_connection_name
}

output "domain_mart_datasets" {
  description = "domain -> mart dataset_id, useful for wiring dbt profiles / debugging"
  value       = { for d, m in module.bigquery : d => m.mart_dataset_id }
}

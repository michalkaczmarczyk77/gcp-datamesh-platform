output "dataset_ids" {
  value = { for layer, ds in google_bigquery_dataset.this : layer => ds.dataset_id }
}

output "mart_dataset_id" {
  value = google_bigquery_dataset.this["mart"].dataset_id
}

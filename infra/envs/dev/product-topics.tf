resource "google_pubsub_schema" "release_event" {
  name       = "data-product-release-v1"
  type       = "AVRO"
  definition = file("${path.module}/../../modules/data_product_topic/release_event.avsc")
}

module "product_topic" {
  for_each         = { for p in local.products : p.topic => p }
  source           = "../../modules/data_product_topic"
  project_id       = var.project_id
  topic_name       = each.key
  schema_id        = google_pubsub_schema.release_event.id
  domain           = each.value.domain
  product          = each.value.name
  consumer_domains = lookup(local.consumers_by_topic, each.key, [])
}

output "topic_id" {
  value = google_pubsub_topic.product.id
}

output "dlq_topic_id" {
  value = google_pubsub_topic.dlq.id
}

output "dlq_triage_subscription_id" {
  value = google_pubsub_subscription.dlq_triage.id
}

output "dlq_alert_policy_name" {
  value = google_monitoring_alert_policy.dlq_backlog.name
}

output "subscription_ids" {
  value = { for domain, sub in google_pubsub_subscription.consumer : domain => sub.id }
}

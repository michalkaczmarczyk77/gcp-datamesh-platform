# Phase 3 / Step 3.3 — each data product gets a topic and one subscription per
# consumer, plus a dead-letter topic. The shared AVRO schema is owned by the
# environment and passed in as schema_id.

data "google_project" "this" {
  project_id = var.project_id
}

resource "google_pubsub_topic" "product" {
  name = var.topic_name # dtp.sales.fct_orders.released
  schema_settings {
    schema   = var.schema_id
    encoding = "JSON"
  }
  message_retention_duration = "604800s" # 7 days: lets a down consumer catch up
  labels                     = { domain = var.domain, product = var.product }
}

resource "google_pubsub_topic" "dlq" {
  name   = "${var.topic_name}.dlq"
  labels = { domain = var.domain, product = var.product, purpose = "dlq" }
}

# Pub/Sub's own service agent needs explicit rights to forward undeliverable
# messages into the DLQ topic — otherwise dead_letter_policy fails silently.
resource "google_pubsub_topic_iam_member" "dlq_publisher" {
  topic  = google_pubsub_topic.dlq.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription" "consumer" {
  for_each                   = toset(var.consumer_domains)
  name                       = "${var.topic_name}.sub.${each.value}"
  topic                      = google_pubsub_topic.product.id
  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  retain_acked_messages      = false
  expiration_policy { ttl = "" } # never expire
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 10
  }
}

# Pub/Sub's service agent also needs subscriber rights on each subscription
# that has a dead_letter_policy attached, to pull-and-forward failed messages.
resource "google_pubsub_subscription_iam_member" "dlq_forwarder" {
  for_each     = google_pubsub_subscription.consumer
  subscription = each.value.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Without a subscription, the DLQ topic has nowhere to hold messages at all —
# they'd be dropped the instant they're forwarded, not retained "forever".
# This gives ops a bounded, pullable window to inspect/replay dead letters
# (`gcloud pubsub subscriptions pull <name> --auto-ack`) before they age out.
resource "google_pubsub_subscription" "dlq_triage" {
  name                       = "${var.topic_name}.dlq.sub.triage"
  topic                      = google_pubsub_topic.dlq.id
  ack_deadline_seconds       = 60
  message_retention_duration = var.dlq_retention_duration
  retain_acked_messages      = false
  expiration_policy { ttl = "" } # never expire the subscription itself; only messages age out
}

# Every event reaching this subscription already exhausted max_delivery_attempts,
# so any backlog above zero is inherently abnormal and worth a human looking at
# before dlq_retention_duration purges it. Requires monitoring.googleapis.com
# enabled on the project (add it alongside the APIs enabled in Phase 1 / Step 1.2).
resource "google_monitoring_alert_policy" "dlq_backlog" {
  display_name = "DLQ backlog — ${var.topic_name}"
  combiner     = "OR"
  severity     = "WARNING"

  conditions {
    display_name = "num_undelivered_messages > 0 on ${google_pubsub_subscription.dlq_triage.name}"
    condition_threshold {
      filter = join(" AND ", [
        "resource.type=\"pubsub_subscription\"",
        "resource.labels.subscription_id=\"${google_pubsub_subscription.dlq_triage.name}\"",
        "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s" # sustained 5 min so a message pulled almost instantly isn't a false positive
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MAX"
      }
      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.dlq_alert_notification_channels

  documentation {
    mime_type = "text/markdown"
    content   = "One or more events for **${var.domain}/${var.product}** exceeded `max_delivery_attempts` and landed on the dead-letter subscription `${google_pubsub_subscription.dlq_triage.name}`. Inspect with `gcloud pubsub subscriptions pull ${google_pubsub_subscription.dlq_triage.name} --auto-ack`, then either fix and republish or acknowledge as a known loss before the ${var.dlq_retention_duration} retention window purges it."
  }

  alert_strategy {
    auto_close = "604800s" # 7 days
  }
}

variable "project_id" {
  type        = string
  description = "Used to resolve the Pub/Sub service agent for the DLQ IAM bindings."
}

variable "topic_name" {
  type        = string
  description = "Fully-qualified topic name, e.g. dtp.sales.fct_orders.released."
}

variable "schema_id" {
  type        = string
  description = "Shared Pub/Sub schema ID for the data-product release event."
}

variable "domain" {
  type        = string
  description = "Producing domain, e.g. sales."
}

variable "product" {
  type        = string
  description = "Product name, e.g. fct_orders."
}

variable "consumer_domains" {
  type        = list(string)
  default     = []
  description = "Domains that consume this product — one subscription is created per entry."
}

variable "dlq_retention_duration" {
  type        = string
  default     = "1209600s" # 14 days
  description = "How long dead-lettered messages stay pullable on the DLQ triage subscription before Pub/Sub purges them (max 31 days). Without this, undelivered messages don't accumulate forever either — they're just never retained anywhere, since the DLQ topic otherwise has no subscription."
}

variable "dlq_alert_notification_channels" {
  type        = list(string)
  default     = []
  description = "Notification channel resource names (format projects/<project>/notificationChannels/<id>, from google_monitoring_notification_channel) to page/email/Slack when a message lands on the DLQ. Left empty by default — the alert policy still fires and shows as an incident in Cloud Monitoring, it just won't notify anyone until channels are supplied."
}

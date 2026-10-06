resource "google_artifact_registry_repository" "dtp-artifact-registry" {
  location      = var.region
  repository_id = "dtp-artifact-registry"
  description   = "Data Platform Docker Registry"
  format        = "DOCKER"
}


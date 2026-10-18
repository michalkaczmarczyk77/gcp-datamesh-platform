resource "kubernetes_namespace_v1" "airflow" {
  metadata {
    name = "airflow2"
  }
}

resource "kubernetes_secret_v1" "postgresql" {
  metadata {
    name      = "airflow-postgresql"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = var.postgres_password
  }

  type = "Opaque"
}

resource "kubernetes_deployment_v1" "postgresql" {
  metadata {
    name      = "airflow-postgresql"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
    labels = {
      app = "airflow-postgresql"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "airflow-postgresql"
      }
    }

    template {
      metadata {
        labels = {
          app = "airflow-postgresql"
        }
      }

      spec {
        security_context {
          fs_group = 999
        }

        container {
          name              = "postgresql"
          image             = "postgres:16"
          image_pull_policy = "IfNotPresent"

          env {
            name  = "POSTGRES_USER"
            value = "airflow"
          }

          env {
            name  = "POSTGRES_DB"
            value = "airflow"
          }

          env {
            name = "POSTGRES_PASSWORD"

            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.postgresql.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          port {
            name           = "postgres"
            container_port = 5432
          }

          startup_probe {
            exec {
              command = ["pg_isready", "-U", "airflow", "-d", "airflow"]
            }

            period_seconds    = 5
            failure_threshold = 30
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "airflow", "-d", "airflow"]
            }

            period_seconds    = 5
            timeout_seconds   = 3
            failure_threshold = 6
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "airflow", "-d", "airflow"]
            }

            period_seconds    = 10
            timeout_seconds   = 3
            failure_threshold = 6
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "postgresql-data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgresql-data"

          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgresql" {
  metadata {
    name      = "airflow-postgresql"
    namespace = kubernetes_namespace_v1.airflow.metadata[0].name
  }

  spec {
    selector = {
      app = "airflow-postgresql"
    }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "elsa_data" {
  metadata {
    name = "elsa-data"
    labels = {
      app = "elsa-data"
    }
  }

  wait_for_rollout = false

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "elsa-data"
      }
    }

    template {
      metadata {
        labels = {
          app = "elsa-data"
        }
      }

      spec {
        enable_service_links = false

        volume {
          name = local.service_account_credentials_name
          secret {
            secret_name = local.service_account_credentials_name
          }
        }

        container {
          image = "edgedb/edgedb:2"
          name = "edgedb"

          env {
            name  = "EDGEDB_SERVER_SECURITY"
            value = "insecure_dev_mode"
          }
          env {
            name = "EDGEDB_SERVER_PASSWORD"
            value_from {
              secret_key_ref {
                name = local.edgedb_credentials_name
                key  = "edgedb_server_password"
              }
            }
          }
          env {
            name = "EDGEDB_SERVER_BACKEND_DSN"
            value_from {
              secret_key_ref {
                name = local.edgedb_credentials_name
                key  = "edgedb_server_backend_dsn"
              }
            }
          }
          env {
            name = "EDGEDB_SERVER_TLS_CERT"
            value_from {
              secret_key_ref {
                name     = local.edgedb_credentials_name
                key      = "edgedb_server_tls_cert"
              }
            }
          }
          env {
            name = "EDGEDB_SERVER_TLS_KEY"
            value_from {
              secret_key_ref {
                name     = local.edgedb_credentials_name
                key      = "edgedb_server_tls_key"
              }
            }
          }

          port {
            container_port = 5656
          }

          liveness_probe {
            http_get {
              path = "/server/status/ready"
              port = 5656
            }
          }

          readiness_probe {
            http_get {
              path = "/server/status/ready"
              port = 5656
            }
          }
        }

        container {
          image = var.elsa_data_image
          name = "elsa-data"

          env {
            name = "ELSA_DATA_META_CONFIG_FOLDERS"
            value = "./config"
          }
          env {
            name = "ELSA_DATA_META_CONFIG_SOURCES"
            value = "file('base') file('dev-common') file('dev-localhost') file('datasets') gcloud-secret('${var.meta_config_resource_id}')"
          }
          env {
            name = "NODE_ENV"
            value = "development"
          }
          env {
            name = "ELSA_DATA_CONFIG_PORT"
            value = "80"
          }
          env {
            name = "EDGEDB_CLIENT_TLS_SECURITY"
            value = "insecure"
          }
          env {
            name = "GOOGLE_APPLICATION_CREDENTIALS"
            value = "/secrets/service-account/credentials.json"
          }
          env {
            name = "EDGEDB_DSN"
            value_from {
              secret_key_ref {
                name     = local.elsa_data_credentials_name
                key      = "edgedb_dsn"
              }
            }
          }

          port {
            container_port = 80
          }

          volume_mount {
            mount_path = "/secrets/service-account"
            name = local.service_account_credentials_name
            read_only = true
          }
        }

        container {
          image = "gcr.io/cloudsql-docker/gce-proxy:1.27.0"
          name = "cloudsql-proxy"

          command = [
            "/cloud_sql_proxy",
            "-credential_file=/secrets/service-account/credentials.json",
          ]

          security_context {
            allow_privilege_escalation = false
            run_as_user = 2
          }

          env {
            name = "INSTANCES"
            value_from {
              secret_key_ref {
                name = local.cloudsql_db_credentials_name
                key = "instance"
              }
            }
          }

          volume_mount {
            mount_path = "/secrets/service-account"
            name = local.service_account_credentials_name
            read_only = true
          }
        }
      }
    }
  }
}

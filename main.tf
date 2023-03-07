terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

variable "google_project_id" {
  type = string
}

variable "google_application_credentials" {
  type = string
}

variable "zone_dns_name" {
  type = string
}

variable "deployment_subdomain" {
  type = string
}

variable "region" {
  type = string
  default = "australia-southeast1"
}

provider "google" {
  credentials = file(pathexpand(var.google_application_credentials))

  project = var.google_project_id
  region  = var.region
  zone    = "${var.region}-c"
}

resource "google_secret_manager_secret" "elsa_data_dev_deployed" {
  secret_id = "ElsaDataDevDeployed"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret" "root_ca_crt" {
  secret_id = "rootCA-crt"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret" "edgedb_dsn" {
  secret_id = "EDGEDB_DSN"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

// TODO
resource "google_dns_managed_zone" "dsp_zone" {
  name        = "dsp"
  dns_name    = "${var.zone_dns_name}."
  description = "DSP zone"
}

resource "google_dns_record_set" "elsa_data_dev" {
  name = "${var.deployment_subdomain}.${var.zone_dns_name}."
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.dsp_zone.name

  rrdatas = [module.lb-http.external_ip]
}

module "lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 6.3"
  name    = "elsa-data-dev-lb"
  project = var.google_project_id

  ssl                             = true
  managed_ssl_certificate_domains = ["${var.deployment_subdomain}.${var.zone_dns_name}"]
  https_redirect                  = true
  labels                          = { "example-label" = "cloud-run-example" }

  backends = {
    default = {
      description = null
      groups = [
        {
          group = google_compute_region_network_endpoint_group.serverless_neg.id
        }
      ]
      enable_cdn              = false
      security_policy         = null
      custom_request_headers  = null
      custom_response_headers = null

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }
      log_config = {
        enable      = false
        sample_rate = null
      }
      protocol         = null
      port_name        = null
      compression_mode = null
    }
  }
}

resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  name                  = "serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.elsa_data_dev.name
  }
}

resource "google_cloud_run_service" "elsa_data_dev" {
  name = "elsa-data-dev"
  location = var.region
  autogenerate_revision_name = true

  template {
    spec {
      containers {
        image = "gcr.io/${var.google_project_id}/elsa-data:dev"
        ports {
          container_port = 80
        }
        env {
          name = "EDGEDB_DSN"
          value_from {
            secret_key_ref {
              key = "latest"
              name = "EDGEDB_DSN"
            }
          }
        }
        env {
          name = "ELSA_DATA_META_CONFIG_FOLDERS"
          value = "./config"
        }
        env {
          name = "ELSA_DATA_META_CONFIG_SOURCES"
          value = "file('base') file('dev-common') file('dev-localhost') file('datasets') gcloud-secret('${google_secret_manager_secret.elsa_data_dev_deployed.id}/versions/latest')"
        }
        env {
          name = "ELSA_DATA_CONFIG_PORT"
          value = "80"
        }
        env {
          name = "NODE_ENV"
          value = "development"
        }
        env {
          name = "EDGEDB_TLS_CA_FILE"
          value = "/mnt/rootca/rootCA.crt/latest"
        }
        resources {
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
        volume_mounts {
          name = "root-ca-secret"
          mount_path = "/mnt/rootca"
        }
      }
      volumes {
        name = "root-ca-secret"
        secret {
          secret_name  = "rootCA-crt"
          items {
            key  = "latest"
            path = "rootCA.crt/latest"
          }
        }
      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "1"
        "autoscaling.knative.dev/maxScale" = "30"
        "run.googleapis.com/cpu-throttling" = "false"
      }
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "all"
      "run.googleapis.com/ingress-status" = "all"
    }
  }
}

resource "google_cloud_run_service_iam_binding" "elsa_data_dev" {
  location = google_cloud_run_service.elsa_data_dev.location
  service  = google_cloud_run_service.elsa_data_dev.name
  role     = "roles/run.invoker"
  members = [
    "allUsers"
  ]
}

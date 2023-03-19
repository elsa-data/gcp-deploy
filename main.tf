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

variable "postgres_user" {
  type = string
}

variable "region" {
  type = string
  default = "australia-southeast1"
}

variable "elsa_data_image" {
  type = string
}

variable "apply_k8s_secrets" {
  type = bool
  default = false
}

locals {
  deployment_fqdn = "${var.deployment_subdomain}.${var.zone_dns_name}"
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

resource "google_dns_managed_zone" "dsp_zone" {
  name        = "dsp"
  dns_name    = "${var.zone_dns_name}."
  description = "DSP zone"
}

resource "google_dns_record_set" "elsa_data_dev" {
  name = "${local.deployment_fqdn}."
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.dsp_zone.name

  rrdatas = [module.elsa_data.ingress_address]
}

resource "google_sql_database_instance" "edgedb_postgres" {
  name             = "edgedb-postgres"
  region           = var.region
  database_version = "POSTGRES_13"
  settings {
    tier = "db-custom-1-3840"
  }

  deletion_protection  = "true"
}

resource "google_sql_user" "edgedb_postgres_users" {
  name     = var.postgres_user
  instance = google_sql_database_instance.edgedb_postgres.name
  password = "changeme"

  lifecycle {
    ignore_changes = [
      password,
    ]
  }
}

resource "google_container_cluster" "elsa_data_k8s" {
  name     = "elsa-data-k8s"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "elsa_data_k8s" {
  name       = "elsa-data-k8s-node-pool"
  cluster    = google_container_cluster.elsa_data_k8s.id
  node_count = 1
}

module "elsa_data" {
  source = "./k8s"

  deployment_fqdn = local.deployment_fqdn
  meta_config_resource_id = "${google_secret_manager_secret.elsa_data_dev_deployed.id}/versions/latest"
  elsa_data_image = var.elsa_data_image
  apply_secrets = var.apply_k8s_secrets
}

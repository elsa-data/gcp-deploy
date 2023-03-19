locals {
  service_account_credentials_name = "service-account-credentials"
  edgedb_credentials_name = "edgedb-credentials"
  elsa_data_credentials_name = "elsa-data-credentials"
  cloudsql_db_credentials_name = "cloudsql-db-credentials"
}

resource "kubernetes_secret_v1" "service_account_credentials" {
  count = var.apply_secrets ? 1 : 0

  metadata {
    name = local.service_account_credentials_name
  }

  data = {
    "credentials.json" = "changeme"
  }
}

resource "kubernetes_secret_v1" "edgedb_credentials" {
  count = var.apply_secrets ? 1 : 0

  metadata {
    name = local.edgedb_credentials_name
  }

  data = {
    edgedb_server_tls_cert    = "change me"
    edgedb_server_tls_key     = "change me"
    edgedb_server_backend_dsn = "change me"
    edgedb_server_password    = "change me"
  }
}

resource "kubernetes_secret_v1" "elsa_data_credentials" {
  count = var.apply_secrets ? 1 : 0

  metadata {
    name = local.elsa_data_credentials_name
  }

  data = {
    edgedb_dsn = "change me"
  }
}

resource "kubernetes_secret_v1" "cloudsql_db_credentials" {
  count = var.apply_secrets ? 1 : 0

  metadata {
    name = local.cloudsql_db_credentials_name
  }

  data = {
    instance = "change me"
  }
}

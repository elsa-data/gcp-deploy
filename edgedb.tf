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
  name     = "postgres"
  instance = google_sql_database_instance.edgedb_postgres.name
  password = "changeme" // TODO: Document that this must be set
}

resource "google_container_cluster" "edgedb_k8s" {
  name     = "edgedb-k8s"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "edgedb_k8s" {
  name       = "edgedb-k8s-node-pool"
  cluster    = google_container_cluster.edgedb_k8s.id
  node_count = 1
}

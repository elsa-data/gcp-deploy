resource "google_sql_database" "database" {
  name     = "my-database"
  instance = google_sql_database_instance.instance.name
}

# See versions at https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance#database_version
resource "google_sql_database_instance" "instance" {
  name             = "edgedb-postgres"
  region           = var.region
  database_version = "POSTGRES_13"
  settings {
    tier = "db-custom-1-3840"
  }

  deletion_protection  = "true"
}

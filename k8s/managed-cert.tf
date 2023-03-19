resource "kubernetes_manifest" "managedcertificate_managed_cert" {
  manifest = {
    "apiVersion" = "networking.gke.io/v1"
    "kind" = "ManagedCertificate"
    "metadata" = {
      "name" = var.managed_cert_name
      "namespace" = "default"
    }
    "spec" = {
      "domains" = [
        var.deployment_fqdn,
      ]
    }
  }
}


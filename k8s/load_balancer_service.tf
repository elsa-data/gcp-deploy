resource "kubernetes_service" "elsa_data" {
  metadata {
    name = "elsa-data"
  }

  spec {
    selector = {
      app = kubernetes_deployment.elsa_data.metadata.0.labels.app
    }

    type = "LoadBalancer"

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }
  }
}

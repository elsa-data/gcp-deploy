resource "kubernetes_service_v1" "elsa_data" {
  metadata {
    name = "ingress-service"
  }
  spec {
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "elsa_data" {
  wait_for_load_balancer = true

  metadata {
    name = "elsa-data-ingress"
    annotations = {
      "networking.gke.io/managed-certificates" = var.managed_cert_name
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service {
              name = kubernetes_service.elsa_data.metadata.0.name
              port {
                number = 80
              }
            }
          }

          path = "/"
          path_type = "Prefix"
        }
      }
    }
  }
}

output "ingress_address" {
  value = kubernetes_ingress_v1.elsa_data.status.0.load_balancer.0.ingress.0.ip
}

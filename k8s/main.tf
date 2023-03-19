provider "kubernetes" {
  config_path = "~/.kube/config"
}

variable "managed_cert_name" {
  type = string
  default = "managed-cert"
}

variable "deployment_fqdn" {
  type = string
}

variable "service_name" {
  type = string
  default = "elsa-data"
}

variable "meta_config_resource_id" {
  type = string
}

variable "elsa_data_image" {
  type = string
}

variable "apply_secrets" {
  type = bool
}

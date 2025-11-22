variable "grafana_url" {
  description = "Grafana URL (http://localhost:3000 for port-forward or http://grafana.monitoring.svc for in-cluster)"
  type        = string
  default     = "http://localhost:3000"
}

variable "grafana_service_account_token" {
  description = "Grafana service account token for Terraform authentication"
  type        = string
  sensitive   = true
}

variable "prometheus_datasource_uid" {
  description = "UID of the Prometheus datasource in Grafana"
  type        = string
  default     = "prometheus"
}

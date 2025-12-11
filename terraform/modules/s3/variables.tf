variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable project_name {
  type    = string
  default = "zendesk-metrics"
}

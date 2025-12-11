# Secrets
resource "aws_secretsmanager_secret" "zendesk_metrics_secrets" {
  name        = local.basepath
  description = "Secrets that are used by the application"
  tags        = local.tags
}

locals {
  aws_region   = "us-east-1"
  project_name = "zendesk-metrics"

  # Artifacts bucket policy ARN (constructed dynamically for PR workspaces)
  
  artifacts_bucket_name       = "${local.project_name}-${var.environment}-build-artifacts"
}

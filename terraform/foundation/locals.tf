locals {
  aws_region   = "us-east-1"
  project_name = "zendesk-metrics"

  github_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com" # TODO
  github_org               = "ustaxcourt"
  github_repo              = "ustc-zendesk-metrics"
  state_bucket_name        = "${local.project_name}-${var.environment}-terraform-state"
  state_lock_table_name    = "${local.project_name}-terraform-locks"
  state_object_keys = [
    "${local.project_name}/foundation.tfstate",
    "${local.project_name}/terraform.tfstate",
  ]
  lambda_exec_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project_name}-lambda-exec" # TODO

  # Artifacts bucket policy ARN (constructed dynamically for PR workspaces)
  artifacts_bucket_name       = "${local.project_name}-${var.environment}-build-artifacts"
}

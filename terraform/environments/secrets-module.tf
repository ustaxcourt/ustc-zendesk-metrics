module "secrets" {
  source               = "../modules/secrets"
  environment          = var.environment
  lambda_exec_role_arn = data.terraform_remote_state.foundation.outputs.lambda_role_arn
  tags = {
    Project = "zendesk-metrics"
    Env     = var.environment
  }
}

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}  

module "iam" {
  source = "../modules/iam"
  tags = {
    Env = var.environment
    Project = "${local.project_name}"
  }
  state_bucket_name                 = "${local.project_name}-${var.environment}-terraform-state"
  state_lock_table_name             = "${local.project_name}-terraform-locks"
  state_object_keys                 = local.state_object_keys
  github_oidc_provider_arn          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
  github_org                        = "ustaxcourt"
  github_repo                       = "ustc-zendesk-metrics"
  lambda_exec_role_arn              = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.project_name}-lambda-exec"
  deploy_role_name                  = "${local.project_name}-cicd-deployer-role"
  artifacts_bucket_name             = "${local.project_name}-${var.environment}-build-artifacts"
  job_queue_arn                     = "arn:aws:sqs:${local.aws_region}:${data.aws_caller_identity.current.account_id}:job-queue"
  dlq_queue_arn                     = "arn:aws:sqs:${local.aws_region}:${data.aws_caller_identity.current.account_id}:job-queue-dlq"
  environment                       = var.environment
  build_artifacts_access_policy_arn = module.artifacts_bucket.build_artifacts_access_policy_arn
}

module "artifacts_bucket" {
  source = "../modules/artifacts_bucket"

  build_artifacts_bucket_name = local.artifacts_bucket_name
  deployer_role_arn           = module.iam.cicd_role_arn
  manage_bucket_policy        = true
}

# Attach artifact bucket policy to deployer role (GitHub Actions --> AWS deployment)
resource "aws_iam_role_policy_attachment" "ci_build_artifacts" {
  role       = module.iam.cicd_role_name
  policy_arn = module.artifacts_bucket.build_artifacts_access_policy_arn
}

resource "aws_iam_openid_connect_provider" "cicd_identity_provider" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
}

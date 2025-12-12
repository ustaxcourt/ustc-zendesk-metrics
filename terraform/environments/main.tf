data "aws_caller_identity" "current" {}

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket         = "${local.project_name}-${var.environment}-terraform-state"
    key            = "${local.project_name}/foundation.tfstate"
    dynamodb_table = "${local.project_name}-terraform-locks"
    region         = "us-east-1"
    # use_lockfile   = true
    encrypt        = true
  }
}

module "lambda" {
  source                    = "../modules/lambda"
  function_name_prefix      = local.project_name
  lambda_execution_role_arn = data.terraform_remote_state.foundation.outputs.lambda_role_arn
  runtime                   = "python3.15"
  
  environment_variables     = {
    ENV                   = var.environment
    METRICS_BUCKET        = module.s3.metrics_bucket_name
    JOB_QUEUE_URL         = module.sqs.job_queue_url
    ATHENA_DATABASE       = module.athena.database_name
    ATHENA_RESULTS_BUCKET = module.athena.athena_results_bucket_name
  }

  artifact_bucket = local.artifacts_bucket_name
  artifact_s3_keys = {
    getReport    = var.getReport_s3_key
    updateMetricsDatabase = var.updateMetricsDatabase_s3_key
    processSqsMessage    = var.processSqsMessage_s3_key
  }
  source_code_hashes = {
    getReport    = var.getReport_source_code_hash
    updateMetricsDatabase = var.updateMetricsDatabase_source_code_hash
    processSqsMessage    = var.processSqsMessage_source_code_hash
  }

  tags = {
    Env     = var.environment
    Project = local.project_name
  }
}

module "api" {
  source = "../modules/api-gateway"

  lambda_function_arns = module.lambda.function_arns
  stage_name           = var.environment
}


resource "aws_cloudwatch_event_rule" "update_metrics_database_cron_rule" {
  name                = "updateMetricsDatabaseCronRule"
  schedule_expression = "cron(0 4 ? * * *)"
}

resource "aws_cloudwatch_event_target" "update_metrics_database_cron_target" {
  rule      = aws_cloudwatch_event_rule.update_metrics_database_cron_rule.name
  target_id = module.lambda.update_metrics_database_function_name
  arn       = module.lambda.update_metrics_database_function_arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_update_metrics_database_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.update_metrics_database_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.update_metrics_database_cron_rule.arn

  lifecycle {
    replace_triggered_by = [
      terraform_data.update_metrics_database_cron_lambda_last_modified
    ]
  }
}
resource "terraform_data" "update_metrics_database_cron_lambda_last_modified" {
  input = module.lambda.update_metrics_database_last_modified
}

module "sqs" {
  source = "../modules/sqs"
}

module "s3" {
  source = "../modules/s3"
  environment = var.environment
  project_name = local.project_name
}

module "athena" {
  source = "../modules/athena"
  environment = var.environment
  project_name = local.project_name
}

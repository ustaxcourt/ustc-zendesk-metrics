locals {
  lambda_functions = {
    updateMetricsDatabase = {
      handler = "lambda_handler.update_metrics_database_handler"
    }
    getReport = {
      handler = "lambda_handler.get_report_handler"
    }
    processSqsMessage = {
      handler = "lambda_handler.process_sqs_message_handler"
    }
  }
}

resource "aws_lambda_function" "functions" {
  for_each = local.lambda_functions

  s3_bucket        = var.artifact_bucket
  s3_key           = var.artifact_s3_keys[each.key]
  source_code_hash = var.source_code_hashes[each.key]

  function_name = "${var.function_name_prefix}-${each.key}"
  role          = var.lambda_execution_role_arn
  handler       = each.value.handler

  runtime = var.runtime
  timeout = var.lambda_timeouts[each.key]

  # Increase /tmp storage to 5GB
  ephemeral_storage {
    size = 5120
  }

  environment {
    variables = var.environment_variables
    
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each          = local.lambda_functions
  name              = "/aws/lambda/${var.function_name_prefix}-${each.key}"
  retention_in_days = var.log_retention_days
  tags              = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Allow the function to invoke itself recursively
resource "aws_lambda_function_recursion_config" "example" {
  function_name  = "${var.function_name_prefix}-processSqsMessage"
  recursive_loop = "Allow"
}

output "lambda_function_arns" {
  description = "Map of Lambda function ARNs keyed by function name"
  value       = module.lambda.function_arns
}

output "lambda_function_names" {
  description = "Map of Lambda function names keyed by function name"
  value       = module.lambda.function_names
}

output "lambda_function_invoke_arns" {
  description = "Map of Lambda function invoke ARNs keyed by function name"
  value       = module.lambda.function_invoke_arns
}

output "api_gateway_url" {
  value       = module.api.api_gateway_url
  description = "Base URL of the API Gateway for integration tests"
}

# output "build_artifacts_bucket_name" {
#   value       = data.aws_s3_bucket.existing_artifacts.bucket
#   description = "Name for build artifacts bucket"
# }

# output "build_artifacts_bucket_arn" {
#   value       = data.aws_s3_bucket.existing_artifacts.arn
#   description = "ARN for build artifacts bucket"
# }

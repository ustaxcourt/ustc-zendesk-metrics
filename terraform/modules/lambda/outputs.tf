output "function_arns" {
  description = "Map of Lambda function ARNs"
  value       = { for k, v in aws_lambda_function.functions : k => v.arn }
}

output "function_names" {
  description = "Map of Lambda function names"
  value       = { for k, v in aws_lambda_function.functions : k => v.function_name }
}

output "function_invoke_arns" {
  description = "Map of Lambda function invoke ARNs"
  value       = { for k, v in aws_lambda_function.functions : k => v.invoke_arn }
}

# Individual outputs for backward compatibility
output "update_metrics_database_function_arn" {
  description = "ARN of the updateMetricsDatabase Lambda function"
  value       = aws_lambda_function.functions["updateMetricsDatabase"].arn
}

output "update_metrics_database_function_name" {
  description = "Name of the updateMetricsDatabase Lambda function"
  value       = aws_lambda_function.functions["updateMetricsDatabase"].function_name
}

output "update_metrics_database_invoke_arn" {
  description = "Invoke ARN of the updateMetricsDatabase Lambda function"
  value       = aws_lambda_function.functions["updateMetricsDatabase"].invoke_arn
}

output "process_sqs_message_function_arn" {
  description = "ARN of the processSqsMessage Lambda function"
  value       = aws_lambda_function.functions["processSqsMessage"].arn
}

output "process_sqs_message_function_name" {
  description = "Name of the processSqsMessage Lambda function"
  value       = aws_lambda_function.functions["processSqsMessage"].function_name
}

output "process_sqs_message_invoke_arn" {
  description = "Invoke ARN of the processSqsMessage Lambda function"
  value       = aws_lambda_function.functions["processSqsMessage"].invoke_arn
}

output "get_report_function_arn" {
  description = "ARN of the getReport Lambda function"
  value       = aws_lambda_function.functions["getReport"].arn
}

output "get_report_function_name" {
  description = "Name of the getReport Lambda function"
  value       = aws_lambda_function.functions["getReport"].function_name
}

output "get_report_invoke_arn" {
  description = "Invoke ARN of the getReport Lambda function"
  value       = aws_lambda_function.functions["getReport"].invoke_arn
}

output "get_report_last_modified" {
  description = "Invoke ARN of the getReport Lambda function"
  value       = aws_lambda_function.functions["getReport"].last_modified
}

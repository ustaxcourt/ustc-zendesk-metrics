variable "function_name_prefix" {
  description = "Prefix for Lambda function names"
  type        = string
  default     = "zendesk-metrics"
}

variable "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role from IAM module"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "python3.8"
}

variable "environment_variables" {
  description = "Environment variables for Lambda functions"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to Lambda functions"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 14
}

variable "artifact_bucket" {
  description = "S3 bucket containing Lambda artifacts"
  type        = string
}

variable "artifact_s3_keys" {
  description = "Map of function names to S3 keys for artifacts"
  type        = map(string)
}

variable "source_code_hashes" {
  description = "Map of function names to base64-encoded SHA256 hashes"
  type        = map(string)
}

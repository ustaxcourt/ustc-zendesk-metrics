variable "tags" {
  description = "Common tags to apply to IAM resources"
  type        = map(string)
  default     = {}
}

variable "assume_role_services" {
  description = "List of AWS services allowed to assume the role"
  type        = list(string)
  default     = ["lambda.amazonaws.com"]
}

variable "attach_basic_execution" {
  description = "Attach AWSLambdaBasicExecutionRole managed policy"
  type        = bool
  default     = true
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
}
variable "project_name" {
  description = "Project name used for tagging and names"
  type        = string
  default     = "zendesk-metrics"
}

variable "lambda_exec_role_arn" {
  type        = string
  description = "Exact Lambda execution role ARN the CI role may pass to functions"
}

variable "deploy_role_name" {
  type        = string
  description = "IAM role name for CI/CD"
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "GitHub OIDC provider ARN in the account"
}

variable "github_org" {
  type        = string
  description = "GitHub org"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo"
}

variable "state_bucket_name" {
  type        = string
  description = "Terraform backend S3 bucket"
}

variable "state_lock_table_name" {
  type        = string
  description = "Terraform DynamoDB lock table"
}

variable "state_object_keys" {
  type        = list(string)
  description = "Exact state S3 object keys the role must manage"
}

variable "artifacts_bucket_name" {
  type        = string
  description = "Name of the artifacts bucket"
}

variable "job_queue_arn" {
  type        = string
  description = "ARN of the job queue"
}

variable "dlq_queue_arn" {
  type        = string
  description = "ARN of the DLQ queue"
}

variable "environment" {
  type = string
  description = "Environment name (dev, prod)"
}

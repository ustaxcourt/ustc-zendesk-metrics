variable "stage_name" {
  description = "Deployment stage name (e.g., dev)"
  type        = string
}

variable "lambda_function_arns" {
  description = "Map of Lambda function ARNs keyed by function name"
  type        = map(string)
}

variable "common_tags" {
  description = "Tags to apply to API resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "getReport_s3_key" {
  description = "S3 key for getReport Lambda artifact"
  type        = string
  default     = ""
}

variable "getReport_source_code_hash" {
  description = "Base64-encoded SHA256 hash for getReport artifact"
  type        = string
  default     = ""
}

variable "processSqsMessage_s3_key" {
  description = "S3 key for processSqsMessage Lambda artifact"
  type        = string
  default     = ""
}

variable "processSqsMessage_source_code_hash" {
  description = "Base64-encoded SHA256 hash for processSqsMessage artifact"
  type        = string
  default     = ""
}

variable "updateMetricsDatabase_s3_key" {
  description = "S3 key for updateMetricsDatabase Lambda artifact"
  type        = string
  default     = ""
}

variable "updateMetricsDatabase_source_code_hash" {
  description = "Base64-encoded SHA256 hash for updateMetricsDatabase artifact"
  type        = string
  default     = ""
}

variable "zendesk_group_id" {
  description = "Zendesk group ID"
  type        = string
  default     = ""
}

variable "cognito_client_id" {
  description = "Cognito client ID"
  type        = string
  default     = ""
}

variable "cognito_user_pool" {
  description = "Cognito user pool"
  type        = string
  default     = ""
}

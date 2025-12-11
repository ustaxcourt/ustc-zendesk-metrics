variable "environment" {
  type = string
}

variable "project" {
  type    = string
  default = "zendesk-metrics"
}

variable "lambda_exec_role_arn" {
  type = string
}

variable "admin_user_name" {
  type = string
  default = "admin-user"
}

variable "ustc_admin_user_name" {
  type = string
  default = "ustc-admin-user"
}

variable "ustc_admin_pass_name" {
  type = string
  default = "ustc-admin-pass"
}

variable "ustc_zendesk_user_name" {
  type = string
  default = "ustc-zendesk-user"
}

variable "ustc_zendesk_pass_name" {
  type = string
  default = "ustc-zendesk-pass"
}

variable "api_token_name" {
  type = string
  default = "api-token"
}

variable "admissions_emails_name" {
  type = string
  default = "admissions-emails"
}

variable "zendesk_signing_secret_name" {
  type = string
  default = "zendesk-signing-secret"
}

variable "tags" {
  type    = map(string)
  default = {}
}

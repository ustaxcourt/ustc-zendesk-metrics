locals {
  env      = var.environment

  basepath = "ZendeskDawson"
  
  tags = merge(var.tags, {
    Project = var.project,
    Env     = local.env
  })

  lambda_exec_role_name = element(
    split("/", var.lambda_exec_role_arn),
    length(split("/", var.lambda_exec_role_arn)) - 1
  )
}

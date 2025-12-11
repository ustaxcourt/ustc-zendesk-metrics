output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.name
}

output "cicd_role_name" {
  value       = aws_iam_role.github_actions_deployer.name
  description = "CI/CD deployer role name"
}

output "cicd_role_arn" {
  value       = aws_iam_role.github_actions_deployer.arn
  description = "CI/CD deployer role ARN"
}

output "database_name" {
  value       = aws_athena_database.metrics_database.name
  description = "Name of the Athena database"
}

output "athena_results_bucket_name" {
  value       = aws_s3_bucket.athena_results_bucket.id
  description = "Name of the Athena results bucket"
}

output "metrics_bucket_name" {
  value       = aws_s3_bucket.metrics_bucket.id
  description = "Name of the metrics bucket"
}

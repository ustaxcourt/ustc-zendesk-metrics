output "job_queue_arn" {
  description = "ARN of the job queue"
  value       = aws_sqs_queue.job_queue.arn
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = aws_sqs_queue.dead_letter_queue.arn
}

output "job_queue_url" {
  description = "URL of the job queue"
  value       = aws_sqs_queue.job_queue.id
}

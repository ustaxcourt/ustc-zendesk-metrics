locals {
  tags = {
    Project   = "zendesk-metrics"
    ManagedBy = "terraform"
    Purpose   = "terraform-backend"
  }

  queue_name = "job-queue"
}

resource "aws_sqs_queue" "job_queue" {
  name                       = local.queue_name
  visibility_timeout_seconds = 600
  tags                       = local.tags
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue" "dead_letter_queue" {
  name                       = "${local.queue_name}-dlq"
  message_retention_seconds  = 1209600
  tags                       = local.tags
}

resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.job_queue.arn
  function_name    = var.lambda_arn
  enabled          = true
  batch_size = 1

}

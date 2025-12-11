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
  visibility_timeout_seconds = 1800
  tags                       = local.tags
  redrive_policy = {
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = 5
  }
}

resource "aws_sqs_queue" "dead_letter_queue" {
  name                       = "${local.queue_name}-dlq"
  visibility_timeout_seconds = 1800
  message_retention_seconds = 1209600
  tags                       = local.tags
}

resource "aws_s3_bucket" "metrics_bucket" {
  bucket = "${var.project_name}-${var.environment}-ticket-data"

  tags = {
    Name      = "${var.project_name}-${var.environment}-ticket-data"
    Project   = var.project_name
    ManagedBy = "terraform"
    Purpose   = "ticket-data"
  }
}


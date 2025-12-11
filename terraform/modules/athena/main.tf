resource "aws_s3_bucket" "athena_database_bucket" {
  bucket = "${var.project_name}-${var.environment}-athena-database"
}

resource "aws_s3_bucket_acl" "athena_results_bucket" {
  bucket = "${var.project_name}-${var.environment}-athena-results"
}

resource "aws_athena_database" "metrics_database" {
  name   = "metrics_database"
  bucket = aws_s3_bucket.athena_database_bucket.id
}

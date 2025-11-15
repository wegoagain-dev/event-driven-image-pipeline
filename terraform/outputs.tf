output "upload_bucket_name" {
  description = "Name of the S3 upload bucket"
  value       = aws_s3_bucket.upload.bucket
}

output "upload_bucket_arn" {
  description = "ARN of the S3 upload bucket"
  value       = aws_s3_bucket.upload.arn
}

output "thumbnail_bucket_name" {
  description = "Name of the S3 thumbnail bucket"
  value       = aws_s3_bucket.thumbnails.bucket
}

output "metadata_queue_url" {
  description = "URL of the SQS metadata queue"
  value       = aws_sqs_queue.metadata.url
}

output "dlq_url" {
  description = "URL of the Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.images.name
}

output "image_processor_function_name" {
  description = "Name of the image processor Lambda function"
  value       = aws_lambda_function.image_processor.function_name
}

output "db_writer_function_name" {
  description = "Name of the database writer Lambda function"
  value       = aws_lambda_function.db_writer.function_name
}

output "dashboard_url" {
  description = "URL to CloudWatch Dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.pipeline.dashboard_name}"
}

output "logs_url" {
  description = "URL to CloudWatch Logs"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups"
}

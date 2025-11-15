# ============================================
# Lambda Functions
# ============================================

resource "aws_lambda_function" "image_processor" {
  filename         = data.archive_file.image_processor.output_path
  function_name    = "${local.name_prefix}-image-processor"
  role             = aws_iam_role.image_processor.arn
  handler          = "index.handler"                                       # knows what python file and function to call
  source_code_hash = data.archive_file.image_processor.output_base64sha256 #detects change in code
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 512

  environment { # from the index.py file
    variables = {
      THUMBNAIL_BUCKET = aws_s3_bucket.thumbnails.bucket
      METADATA_QUEUE   = aws_sqs_queue.metadata.url
      THUMBNAIL_SIZE   = "200"
    }
  }
}

# Grant S3 permission to invoke Lambda, controls who can invoke the lambda function, IAM is what lambda can do
resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.upload.arn
}


resource "aws_lambda_function" "db_writer" {
  filename         = data.archive_file.db_writer.output_path
  function_name    = "${local.name_prefix}-db-writer"
  role             = aws_iam_role.db_writer.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.db_writer.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.images.name
    }
  }
}

# SQS Event Source Mapping - connects sqs to lambda
resource "aws_lambda_event_source_mapping" "sqs_to_db_writer" {
  event_source_arn = aws_sqs_queue.metadata.arn
  function_name    = aws_lambda_function.db_writer.arn
  batch_size       = 10
  enabled          = true
}

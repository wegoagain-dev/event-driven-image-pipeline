# ============================================
# S3 Buckets
# ============================================

# Upload Bucket - creates bucket for images and thumbnails
resource "aws_s3_bucket" "upload" {
  bucket = "${local.name_prefix}-uploads-${data.aws_caller_identity.current.account_id}"
}

# turning on versioning helps if i were to upload an file with same name, versioning will keep the old version
resource "aws_s3_bucket_versioning" "upload" {
  bucket = aws_s3_bucket.upload.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "upload" {
  bucket = aws_s3_bucket.upload.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access completely
resource "aws_s3_bucket_public_access_block" "upload" {
  bucket = aws_s3_bucket.upload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Event Notification, when .jpg or .png uploaded trigger image_processor lambda function
resource "aws_s3_bucket_notification" "upload" {
  bucket = aws_s3_bucket.upload.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".png"
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}


# Thumbnail Bucket - Where processed thumbnails are stored
resource "aws_s3_bucket" "thumbnails" {
  bucket = "${local.name_prefix}-thumbnails-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to delete old thumbnails (optional cost optimization)
resource "aws_s3_bucket_lifecycle_configuration" "thumbnails" {
  bucket = aws_s3_bucket.thumbnails.id

  rule {
    id     = "delete-old-thumbnails"
    status = "Enabled"

    expiration {
      days = 90 # Adjust based on your retention requirements
    }
  }
}

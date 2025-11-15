# ============================================
# IAM Roles and Policies
# ============================================

# Role = A "hat" with permissions
# - Services (Lambda, EC2) wear the hat
# - While wearing hat, service gets permissions
# - Service takes off hat when done

# Image Processor Lambda Role
resource "aws_iam_role" "image_processor" {
  name = "${local.name_prefix}-image-processor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy = List of permissions
# - Attached to a role
# - Defines what actions the role can perform
# - Principle of Least Privilege: Give only what's needed

# Policy Structure:
# {
#   "Effect": "Allow" or "Deny",
#   "Action": ["service:Action"],      // What can be done
#   "Resource": "arn:aws:..."          // On what resources
# }

# Image Processor Lambda Policy
resource "aws_iam_role_policy" "image_processor" {
  name = "${local.name_prefix}-image-processor-policy"
  role = aws_iam_role.image_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.upload.arn}/*" # items in bucket not bucket itslef
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.thumbnails.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.metadata.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Database Writer Lambda Role
resource "aws_iam_role" "db_writer" {
  name = "${local.name_prefix}-db-writer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Database Writer Lambda Policy
resource "aws_iam_role_policy" "db_writer" {
  name = "${local.name_prefix}-db-writer-policy"
  role = aws_iam_role.db_writer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.metadata.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = aws_dynamodb_table.images.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

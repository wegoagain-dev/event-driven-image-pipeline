# ============================================
# SQS Queues
# ============================================

# Dead Letter Queue - Captures failed messages, 14 days max
# without DLQ, itll try forever, with DLQ, itll try 3 times before sending to DLQ
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name_prefix}-dlq"
  message_retention_seconds = 1209600 # 14 days
}

# Main Queue - Holds metadata for DB writes
resource "aws_sqs_queue" "metadata" {
  name                       = "${local.name_prefix}-metadata"
  visibility_timeout_seconds = 300    # 5 minutes (should be 6x Lambda timeout)
  message_retention_seconds  = 345600 # 4 days

  # Configure DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3 # Retry 3 times before sending to DLQ
  })
}

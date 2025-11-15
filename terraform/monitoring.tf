# ============================================
# CloudWatch Alarms
# ============================================

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${local.name_prefix}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300 # 5 minutes
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when messages appear in DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name # specifies the queue name for the alarm
  }
}

# Every 5 minutes (period = 300):
#   1. CloudWatch gets metric: ApproximateNumberOfMessagesVisible
#   2. Calculates statistic: Sum of all data points
#   3. Compares: Is Sum > 0? (comparison_operator + threshold)
#   4. Check evaluation_periods: Has this been true for 1 period?
#   5. If YES: State = ALARM 🚨
#   6. If NO: State = OK ✅

resource "aws_cloudwatch_metric_alarm" "image_processor_errors" {
  alarm_name          = "${local.name_prefix}-processor-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Alert when image processor has errors"

  dimensions = {
    FunctionName = aws_lambda_function.image_processor.function_name
  }
}



# ============================================
# CloudWatch Dashboard
# ============================================

resource "aws_cloudwatch_dashboard" "pipeline" {
  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", label = "Image Processor Invocations" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Lambda Invocations"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", { stat = "Average", label = "Avg Processing Time" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "Average Processing Time (ms)"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { label = "Messages in Queue" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "SQS Queue Depth"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible",
            { stat = "Sum", label = "DLQ Messages", color = "#FF0000" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Dead Letter Queue"
        }
      }
    ]
  })
}

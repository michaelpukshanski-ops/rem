# SQS Queue for Transcription Jobs

resource "aws_sqs_queue" "transcription_jobs" {
  name                       = "${var.project_name}-transcription-jobs-${var.environment}"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention
  receive_wait_time_seconds  = 20  # Enable long polling
  
  # Dead letter queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.transcription_dlq.arn
    maxReceiveCount     = 3
  })
  
  tags = {
    Name = "REM Transcription Jobs Queue"
  }
}

# Dead Letter Queue for failed transcription jobs
resource "aws_sqs_queue" "transcription_dlq" {
  name                      = "${var.project_name}-transcription-dlq-${var.environment}"
  message_retention_seconds = 1209600  # 14 days
  
  tags = {
    Name = "REM Transcription DLQ"
  }
}

# CloudWatch alarm for DLQ messages
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project_name}-transcription-dlq-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when messages appear in transcription DLQ"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    QueueName = aws_sqs_queue.transcription_dlq.name
  }
  
  # Add SNS topic for notifications if needed
  # alarm_actions = [aws_sns_topic.alerts.arn]
}

# SQS Queue Policy to allow S3 and Lambda to send messages
resource "aws_sqs_queue_policy" "transcription_jobs" {
  queue_url = aws_sqs_queue.transcription_jobs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.transcription_jobs.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.transcription_dispatcher.arn
          }
        }
      }
    ]
  })
}


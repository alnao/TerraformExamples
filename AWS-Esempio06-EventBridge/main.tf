terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# S3 Bucket che genera eventi
resource "aws_s3_bucket" "source" {
  bucket        = var.source_bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# Abilita notifiche eventi S3
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket      = aws_s3_bucket.source.id
  eventbridge = var.enable_eventbridge_notification
}

# IAM Role per Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.lambda_function_name}-role"

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

  tags = var.tags
}

# Policy per S3 access
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "${var.lambda_function_name}-s3-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetObjectAttributes"
        ]
        Resource = [
          aws_s3_bucket.source.arn,
          "${aws_s3_bucket.source.arn}/*"
        ]
      }
    ]
  })
}

# Attach basic execution role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Function Code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = var.lambda_code
    filename = "lambda_function.py"
  }
}

# Lambda Function
resource "aws_lambda_function" "processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = merge(
      {
        SOURCE_BUCKET = aws_s3_bucket.source.id
      },
      var.lambda_environment_variables
    )
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# EventBridge Rule per S3 Object Created
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = var.eventbridge_rule_name
  description = "Trigger quando un file viene caricato in S3"
  state       = var.eventbridge_rule_state

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = var.event_detail_types
    detail = {
      bucket = {
        name = [aws_s3_bucket.source.id]
      }
      object = {
        key = var.object_key_patterns
      }
    }
  })

  tags = var.tags
}

# EventBridge Target - Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "lambda-target"
  arn       = aws_lambda_function.processor.arn

  # Input transformer (opzionale)
  dynamic "input_transformer" {
    for_each = var.use_input_transformer ? [1] : []
    content {
      input_paths = {
        bucket = "$.detail.bucket.name"
        key    = "$.detail.object.key"
        size   = "$.detail.object.size"
        time   = "$.time"
      }
      input_template = var.input_template
    }
  }

  # Retry policy
  retry_policy {
    maximum_event_age       = var.maximum_event_age
    maximum_retry_attempts  = var.maximum_retry_attempts
  }

  # Dead letter queue (opzionale)
  dynamic "dead_letter_config" {
    for_each = var.dlq_arn != "" ? [1] : []
    content {
      arn = var.dlq_arn
    }
  }
}

# Lambda Permission per EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}

# EventBridge Rule aggiuntive (opzionale)
resource "aws_cloudwatch_event_rule" "s3_object_deleted" {
  count       = var.enable_delete_trigger ? 1 : 0
  name        = "${var.eventbridge_rule_name}-delete"
  description = "Trigger quando un file viene eliminato da S3"
  state       = var.eventbridge_rule_state

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Deleted"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.source.id]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda_target_delete" {
  count     = var.enable_delete_trigger ? 1 : 0
  rule      = aws_cloudwatch_event_rule.s3_object_deleted[0].name
  target_id = "lambda-target-delete"
  arn       = aws_lambda_function.processor.arn
}

resource "aws_lambda_permission" "allow_eventbridge_delete" {
  count         = var.enable_delete_trigger ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_deleted[0].arn
}

# CloudWatch Metric Filter per monitoring
resource "aws_cloudwatch_log_metric_filter" "lambda_errors" {
  count          = var.enable_metric_filter ? 1 : 0
  name           = "${var.lambda_function_name}-errors"
  pattern        = "[ERROR]"
  log_group_name = aws_cloudwatch_log_group.lambda_logs.name

  metric_transformation {
    name      = "LambdaErrors"
    namespace = "CustomMetrics/${var.lambda_function_name}"
    value     = "1"
  }
}

# CloudWatch Alarm per errori Lambda
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count               = var.enable_error_alarm ? 1 : 0
  alarm_name          = "${var.lambda_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_alarm_threshold
  alarm_description   = "Lambda function errors from EventBridge"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = aws_lambda_function.processor.function_name
  }

  tags = var.tags
}

# CloudWatch Alarm per EventBridge failed invocations
resource "aws_cloudwatch_metric_alarm" "eventbridge_failed_invocations" {
  count               = var.enable_failed_invocations_alarm ? 1 : 0
  alarm_name          = "${var.eventbridge_rule_name}-failed-invocations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FailedInvocations"
  namespace           = "AWS/Events"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.failed_invocations_threshold
  alarm_description   = "EventBridge failed invocations"
  alarm_actions       = var.alarm_actions

  dimensions = {
    RuleName = aws_cloudwatch_event_rule.s3_object_created.name
  }

  tags = var.tags
}

# SQS Dead Letter Queue (opzionale)
resource "aws_sqs_queue" "dlq" {
  count                     = var.create_dlq ? 1 : 0
  name                      = "${var.lambda_function_name}-dlq"
  message_retention_seconds = var.dlq_message_retention_seconds
  tags                      = var.tags
}

# SQS Policy per EventBridge
resource "aws_sqs_queue_policy" "dlq_policy" {
  count     = var.create_dlq ? 1 : 0
  queue_url = aws_sqs_queue.dlq[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.s3_object_created.arn
          }
        }
      }
    ]
  })
}

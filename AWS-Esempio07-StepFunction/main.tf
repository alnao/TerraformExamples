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

# S3 Buckets
resource "aws_s3_bucket" "source" {
  bucket        = var.source_bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

resource "aws_s3_bucket" "destination" {
  bucket        = var.destination_bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# S3 Notification per EventBridge
resource "aws_s3_bucket_notification" "source_notification" {
  bucket      = aws_s3_bucket.source.id
  eventbridge = true
}

# IAM Role per Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "${var.step_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
  tags = var.tags
}

# IAM Policy per Step Functions
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.step_function_name}-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:CopyObject"
        ]
        Resource = [
          "${aws_s3_bucket.source.arn}/*",
          "${aws_s3_bucket.destination.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.logger.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.logger_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Logger Function
data "archive_file" "lambda_logger_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_logger.zip"

  source {
    content  = file("${path.module}/lambda_function.py")
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "logger" {
  filename         = data.archive_file.lambda_logger_zip.output_path
  function_name    = var.logger_function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_logger_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 128
  tags            = var.tags
}

# CloudWatch Log Group per Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.logger_function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# CloudWatch Log Group per Step Functions
resource "aws_cloudwatch_log_group" "step_functions_logs" {
  name              = "/aws/vendedlogs/states/${var.step_function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Step Function State Machine
resource "aws_sfn_state_machine" "main" {
  name     = var.step_function_name
  role_arn = aws_iam_role.step_functions_role.arn

  definition = templatefile("${path.module}/step_function_definition.json", {
    logger_function_arn = aws_lambda_function.logger.arn
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions_logs.arn}:*"
    include_execution_data = true
    level                  = var.step_function_log_level
  }

  tracing_configuration {
    enabled = var.enable_xray_tracing
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.step_functions_logs]
}

# EventBridge Rule per trigger Step Function
resource "aws_cloudwatch_event_rule" "s3_upload" {
  name        = "${var.step_function_name}-trigger"
  description = "Trigger Step Function su S3 upload"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.source.id]
      }
    }
  })

  tags = var.tags
}

# EventBridge Target
resource "aws_cloudwatch_event_target" "step_function" {
  rule     = aws_cloudwatch_event_rule.s3_upload.name
  arn      = aws_sfn_state_machine.main.arn
  role_arn = aws_iam_role.eventbridge_role.arn

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    input_template = <<EOF
{
  "sourceBucket": <bucket>,
  "destinationBucket": "${aws_s3_bucket.destination.id}",
  "objectKey": <key>
}
EOF
  }
}

# IAM Role per EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.step_function_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_policy" {
  name = "${var.step_function_name}-eventbridge-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.main.arn
    }]
  })
}

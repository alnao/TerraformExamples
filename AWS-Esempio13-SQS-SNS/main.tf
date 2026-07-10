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

# 1. DynamoDB Table per il log delle invocazioni
resource "aws_dynamodb_table" "logs" {
  name         = var.dynamodb_table_name
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}

# 2. SQS Queue per la ricezione dei messaggi inviati dalla Lambda
resource "aws_sqs_queue" "main" {
  name                      = var.sqs_queue_name
  message_retention_seconds = var.sqs_message_retention_seconds
  tags                      = var.tags
}

# 3. SNS Topic per invio notifiche mail
resource "aws_sns_topic" "main" {
  name = var.sns_topic_name
  tags = var.tags
}

# 4. Email subscription al topic (se configurata)
resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.main.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# 5. IAM Role per Lambda
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

# 6. IAM Policy per accesso a DynamoDB, SQS e SNS
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.lambda_function_name}-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:DescribeTable"
        ]
        Resource = aws_dynamodb_table.logs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.main.arn
      }
    ]
  })
}

# Attachment del ruolo basic execution per scrivere log su CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 7. CloudWatch Log Group per la Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# 8. Compilazione pacchetto ZIP della Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# 9. Lambda Function
resource "aws_lambda_function" "main" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_role.arn
  handler          = var.lambda_handler
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.logs.name
      SQS_QUEUE_URL  = aws_sqs_queue.main.id
      SNS_TOPIC_ARN  = aws_sns_topic.main.arn
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

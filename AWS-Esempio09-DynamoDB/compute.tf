# S3 Bucket for triggering Lambda via EventBridge
resource "aws_s3_bucket" "trigger_bucket" {
  count         = var.enable_s3_lambda_integration ? 1 : 0
  bucket        = "${var.table_name}-trigger-bucket"
  force_destroy = true
  tags          = var.tags
}

# Enable EventBridge notifications for S3 bucket
resource "aws_s3_bucket_notification" "bucket_notification" {
  count       = var.enable_s3_lambda_integration ? 1 : 0
  bucket      = aws_s3_bucket.trigger_bucket[0].id
  eventbridge = true
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  count = var.enable_s3_lambda_integration ? 1 : 0
  name  = "${var.table_name}-lambda-role"

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

# Lambda DynamoDB Policy
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  count = var.enable_s3_lambda_integration ? 1 : 0
  name  = "dynamodb-access"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem"
      ]
      Resource = aws_dynamodb_table.main.arn
    }]
  })
}

# Lambda S3 Read Policy (optional, for additional S3 operations)
resource "aws_iam_role_policy" "lambda_s3_policy" {
  count = var.enable_s3_lambda_integration ? 1 : 0
  name  = "s3-read-access"
  role  = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetObjectMetadata"
      ]
      Resource = "${aws_s3_bucket.trigger_bucket[0].arn}/*"
    }]
  })
}

# Lambda Basic Execution Role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = var.enable_s3_lambda_integration ? 1 : 0
  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function - S3 to DynamoDB
data "archive_file" "lambda_s3_dynamodb_zip" {
  count       = var.enable_s3_lambda_integration ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/lambda_s3_to_dynamodb.zip"
  source_file = "${path.module}/lambda_s3_to_dynamodb.py"
}

resource "aws_lambda_function" "s3_to_dynamodb" {
  count            = var.enable_s3_lambda_integration ? 1 : 0
  filename         = data.archive_file.lambda_s3_dynamodb_zip[0].output_path
  function_name    = "${var.table_name}-s3-to-dynamodb"
  role            = aws_iam_role.lambda_role[0].arn
  handler         = "lambda_s3_to_dynamodb.lambda_handler"
  source_code_hash = data.archive_file.lambda_s3_dynamodb_zip[0].output_base64sha256
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.main.name
    }
  }

  tags = var.tags
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  count             = var.enable_s3_lambda_integration ? 1 : 0
  name              = "/aws/lambda/${aws_lambda_function.s3_to_dynamodb[0].function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# EventBridge Rule for S3 Object Created events
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  count       = var.enable_s3_lambda_integration ? 1 : 0
  name        = "${var.table_name}-s3-object-created"
  description = "Capture S3 Object Created events"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.trigger_bucket[0].id]
      }
    }
  })

  tags = var.tags
}

# EventBridge Target - Lambda
resource "aws_cloudwatch_event_target" "lambda_target" {
  count     = var.enable_s3_lambda_integration ? 1 : 0
  rule      = aws_cloudwatch_event_rule.s3_object_created[0].name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.s3_to_dynamodb[0].arn
}

# Lambda Permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.enable_s3_lambda_integration ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_dynamodb[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created[0].arn
}

# Optional: EventBridge Rule for S3 Object Deleted events
resource "aws_cloudwatch_event_rule" "s3_object_deleted" {
  count       = var.enable_s3_lambda_integration && var.enable_delete_tracking ? 1 : 0
  name        = "${var.table_name}-s3-object-deleted"
  description = "Capture S3 Object Deleted events"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Deleted"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.trigger_bucket[0].id]
      }
    }
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda_target_delete" {
  count     = var.enable_s3_lambda_integration && var.enable_delete_tracking ? 1 : 0
  rule      = aws_cloudwatch_event_rule.s3_object_deleted[0].name
  target_id = "LambdaTargetDelete"
  arn       = aws_lambda_function.s3_to_dynamodb[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_delete" {
  count         = var.enable_s3_lambda_integration && var.enable_delete_tracking ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeDelete"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_to_dynamodb[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_deleted[0].arn
}

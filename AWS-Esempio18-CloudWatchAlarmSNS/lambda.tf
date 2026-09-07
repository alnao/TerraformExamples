# ====================================
# ARCHIVI ZIP
# ====================================

data "archive_file" "sns_to_dynamo" {
  type        = "zip"
  output_path = "${path.module}/lambda_sns_to_dynamo.zip"
  source {
    content  = file("${path.module}/lambda_functions/sns_to_dynamo.py")
    filename = "sns_to_dynamo.py"
  }
}

data "archive_file" "list_alarms" {
  type        = "zip"
  output_path = "${path.module}/lambda_list_alarms.zip"
  source {
    content  = file("${path.module}/lambda_functions/list_alarms.py")
    filename = "list_alarms.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

# ====================================
# RUOLO IAM DELLE LAMBDA
# ====================================

resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

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

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:Scan",
      ]
      Resource = aws_dynamodb_table.allarmi.arn
    }]
  })
}

# ====================================
# LAMBDA 1 - sns_to_dynamo
# Trigger: notifica del topic SNS scritta dall'allarme CloudWatch
# ====================================

resource "aws_cloudwatch_log_group" "lambda_sns_to_dynamo" {
  name              = "/aws/lambda/${local.lambda_sns_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "sns_to_dynamo" {
  function_name    = local.lambda_sns_name
  filename         = data.archive_file.sns_to_dynamo.output_path
  source_code_hash = data.archive_file.sns_to_dynamo.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "sns_to_dynamo.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.allarmi.name
      TTL_DAYS   = var.ttl_days
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_sns_to_dynamo]
  tags       = local.common_tags
}

# ====================================
# LAMBDA 2 - list_alarms
# Trigger: GET /allarmi dell'API Gateway
# ====================================

resource "aws_cloudwatch_log_group" "lambda_list_alarms" {
  name              = "/aws/lambda/${local.lambda_list_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "list_alarms" {
  function_name    = local.lambda_list_name
  filename         = data.archive_file.list_alarms.output_path
  source_code_hash = data.archive_file.list_alarms.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "list_alarms.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.allarmi.name
      CORS_ORIGIN = var.cors_allowed_origin
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_list_alarms]
  tags       = local.common_tags
}

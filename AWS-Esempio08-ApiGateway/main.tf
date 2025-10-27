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

# S3 Bucket per GET method
resource "aws_s3_bucket" "files" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
  tags          = var.tags
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.api_name}-lambda-role"

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

# Lambda S3 Policy
resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "s3-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:ListBucket",
        "s3:GetObject"
      ]
      Resource = [
        aws_s3_bucket.files.arn,
        "${aws_s3_bucket.files.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function 1 - List S3 Files (GET)
data "archive_file" "lambda_list_files_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_list_files.zip"

  source {
    content  = var.lambda_list_files_code
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "list_files" {
  filename         = data.archive_file.lambda_list_files_zip.output_path
  function_name    = "${var.api_name}-list-files"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_list_files_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 128

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.files.id
    }
  }

  tags = var.tags
}

# Lambda Function 2 - Calculate Hypotenuse (POST)
data "archive_file" "lambda_hypotenuse_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_hypotenuse.zip"

  source {
    content  = var.lambda_hypotenuse_code
    filename = "lambda_function.py"
  }
}

resource "aws_lambda_function" "calculate_hypotenuse" {
  filename         = data.archive_file.lambda_hypotenuse_zip.output_path
  function_name    = "${var.api_name}-calculate-hypotenuse"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_hypotenuse_zip.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30
  memory_size     = 128

  tags = var.tags
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "list_files_logs" {
  name              = "/aws/lambda/${aws_lambda_function.list_files.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "hypotenuse_logs" {
  name              = "/aws/lambda/${aws_lambda_function.calculate_hypotenuse.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = var.api_name
  description = "API Gateway con GET e POST methods"

  endpoint_configuration {
    types = [var.endpoint_type]
  }

  tags = var.tags
}

# Resource /files
resource "aws_api_gateway_resource" "files" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "files"
}

# GET /files
resource "aws_api_gateway_method" "get_files" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files.id
  http_method   = "GET"
  authorization = var.authorization_type
  api_key_required = var.api_key_required
}

resource "aws_api_gateway_integration" "get_files" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files.id
  http_method = aws_api_gateway_method.get_files.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_files.invoke_arn
}

# Resource /calculate
resource "aws_api_gateway_resource" "calculate" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "calculate"
}

# POST /calculate
resource "aws_api_gateway_method" "post_calculate" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.calculate.id
  http_method   = "POST"
  authorization = var.authorization_type
  api_key_required = var.api_key_required
}

resource "aws_api_gateway_integration" "post_calculate" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.calculate.id
  http_method = aws_api_gateway_method.post_calculate.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.calculate_hypotenuse.invoke_arn
}

# CORS
resource "aws_api_gateway_method" "options_files" {
  count         = var.enable_cors ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_files" {
  count       = var.enable_cors ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files.id
  http_method = aws_api_gateway_method.options_files[0].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Deploy
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.files.id,
      aws_api_gateway_method.get_files.id,
      aws_api_gateway_integration.get_files.id,
      aws_api_gateway_resource.calculate.id,
      aws_api_gateway_method.post_calculate.id,
      aws_api_gateway_integration.post_calculate.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.get_files,
    aws_api_gateway_integration.get_files,
    aws_api_gateway_method.post_calculate,
    aws_api_gateway_integration.post_calculate
  ]
}

# Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  xray_tracing_enabled = var.enable_xray_tracing

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Permissions
resource "aws_lambda_permission" "apigw_list_files" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_files.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_hypotenuse" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.calculate_hypotenuse.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Usage Plan (opzionale)
resource "aws_api_gateway_usage_plan" "main" {
  count = var.create_usage_plan ? 1 : 0
  name  = "${var.api_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = var.quota_limit
    period = "DAY"
  }

  throttle_settings {
    burst_limit = var.throttle_burst_limit
    rate_limit  = var.throttle_rate_limit
  }

  tags = var.tags
}

# API Key (opzionale)
resource "aws_api_gateway_api_key" "main" {
  count   = var.api_key_required ? 1 : 0
  name    = "${var.api_name}-key"
  enabled = true
  tags    = var.tags
}

resource "aws_api_gateway_usage_plan_key" "main" {
  count         = var.api_key_required && var.create_usage_plan ? 1 : 0
  key_id        = aws_api_gateway_api_key.main[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main[0].id
}

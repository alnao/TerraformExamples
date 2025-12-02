# ====================================
# API GATEWAY
# ====================================

resource "aws_api_gateway_rest_api" "main" {
  name        = var.api_name
  description = "API Gateway per ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# Resource /presigned-url
resource "aws_api_gateway_resource" "presigned_url" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "presigned-url"
}

resource "aws_api_gateway_method" "presigned_url_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.presigned_url.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "presigned_url" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.presigned_url.id
  http_method             = aws_api_gateway_method.presigned_url_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.presigned_url.invoke_arn
}

# Resource /extract-zip
resource "aws_api_gateway_resource" "extract_zip" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "extract-zip"
}

resource "aws_api_gateway_method" "extract_zip_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.extract_zip.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "extract_zip" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.extract_zip.id
  http_method             = aws_api_gateway_method.extract_zip_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.extract_zip.invoke_arn
}

# Resource /excel-to-csv
resource "aws_api_gateway_resource" "excel_to_csv" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "excel-to-csv"
}

resource "aws_api_gateway_method" "excel_to_csv_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.excel_to_csv.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "excel_to_csv" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.excel_to_csv.id
  http_method             = aws_api_gateway_method.excel_to_csv_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.excel_to_csv.invoke_arn
}

# Resource /upload-to-rds
resource "aws_api_gateway_resource" "upload_to_rds" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "upload-to-rds"
}

resource "aws_api_gateway_method" "upload_to_rds_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload_to_rds.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_to_rds" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.upload_to_rds.id
  http_method             = aws_api_gateway_method.upload_to_rds_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.upload_to_rds.invoke_arn
}

# Resource /sftp-send
resource "aws_api_gateway_resource" "sftp_send" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "sftp-send"
}

resource "aws_api_gateway_method" "sftp_send_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.sftp_send.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "sftp_send" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.sftp_send.id
  http_method             = aws_api_gateway_method.sftp_send_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.sftp_send.invoke_arn
}

# Resource /files
resource "aws_api_gateway_resource" "files" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "files"
}

resource "aws_api_gateway_method" "files_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "files" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.files.id
  http_method             = aws_api_gateway_method.files_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_files.invoke_arn
}

# Resource /files/search
resource "aws_api_gateway_resource" "files_search" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.files.id
  path_part   = "search"
}

resource "aws_api_gateway_method" "files_search_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files_search.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "files_search" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.files_search.id
  http_method             = aws_api_gateway_method.files_search_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_files.invoke_arn
}

# Deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.presigned_url.id,
      aws_api_gateway_method.presigned_url_post.id,
      aws_api_gateway_integration.presigned_url.id,
      aws_api_gateway_resource.extract_zip.id,
      aws_api_gateway_method.extract_zip_post.id,
      aws_api_gateway_integration.extract_zip.id,
      aws_api_gateway_resource.excel_to_csv.id,
      aws_api_gateway_method.excel_to_csv_post.id,
      aws_api_gateway_integration.excel_to_csv.id,
      aws_api_gateway_resource.upload_to_rds.id,
      aws_api_gateway_method.upload_to_rds_post.id,
      aws_api_gateway_integration.upload_to_rds.id,
      aws_api_gateway_resource.sftp_send.id,
      aws_api_gateway_method.sftp_send_post.id,
      aws_api_gateway_integration.sftp_send.id,
      aws_api_gateway_resource.files.id,
      aws_api_gateway_method.files_get.id,
      aws_api_gateway_integration.files.id,
      aws_api_gateway_resource.files_search.id,
      aws_api_gateway_method.files_search_get.id,
      aws_api_gateway_integration.files_search.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.api_stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = local.common_tags
}

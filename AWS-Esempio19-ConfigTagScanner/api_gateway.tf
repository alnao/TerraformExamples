# ====================================
# API GATEWAY REST
#   GET /compliance -> lambda list_compliance
# ====================================

resource "aws_api_gateway_rest_api" "main" {
  name        = local.api_name
  description = "API REST per ${var.project_name}: stato di conformita' ai tag obbligatori"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "compliance" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "compliance"
}

resource "aws_api_gateway_method" "compliance_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "compliance_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.compliance.id
  http_method             = aws_api_gateway_method.compliance_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_compliance.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_compliance.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ---- CORS: OPTIONS per il preflight ----
# La pagina sta su un bucket S3, l'API su execute-api: domini diversi.
locals {
  cors_allow_origin  = "'${var.cors_allowed_origin}'"
  cors_allow_headers = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
}

resource "aws_api_gateway_method" "compliance_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "compliance_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.compliance.id
  http_method = aws_api_gateway_method.compliance_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "compliance_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.compliance.id
  http_method = aws_api_gateway_method.compliance_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "compliance_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.compliance.id
  http_method = aws_api_gateway_method.compliance_options.http_method
  status_code = aws_api_gateway_method_response.compliance_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_allow_origin
    "method.response.header.Access-Control-Allow-Headers" = local.cors_allow_headers
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }

  depends_on = [aws_api_gateway_integration.compliance_options]
}

# ---- Deployment + Stage ----
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.compliance.id,
      aws_api_gateway_method.compliance_get.id,
      aws_api_gateway_integration.compliance_get.id,
      aws_api_gateway_method.compliance_options.id,
      aws_api_gateway_integration.compliance_options.id,
      aws_api_gateway_integration_response.compliance_options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.compliance_get,
    aws_api_gateway_integration.compliance_options,
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name
  tags          = local.common_tags
}

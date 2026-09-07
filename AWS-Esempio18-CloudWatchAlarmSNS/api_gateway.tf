# ====================================
# API GATEWAY REST
#   GET /allarmi  -> lambda list_alarms
# ====================================

resource "aws_api_gateway_rest_api" "main" {
  name        = local.api_name
  description = "API REST per ${var.project_name}: storico degli allarmi salvato su DynamoDB"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

resource "aws_api_gateway_resource" "allarmi" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "allarmi"
}

resource "aws_api_gateway_method" "allarmi_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.allarmi.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.limit"      = false
    "method.request.querystring.alarm_name" = false
  }
}

resource "aws_api_gateway_integration" "allarmi_get" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.allarmi.id
  http_method             = aws_api_gateway_method.allarmi_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_alarms.invoke_arn
}

resource "aws_lambda_permission" "apigw_list_alarms" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_alarms.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ---- Deployment + Stage ----
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.allarmi.id,
      aws_api_gateway_method.allarmi_get.id,
      aws_api_gateway_integration.allarmi_get.id,
      aws_api_gateway_method.allarmi_options.id,
      aws_api_gateway_integration.allarmi_options.id,
      aws_api_gateway_integration_response.allarmi_options.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.allarmi_get,
    aws_api_gateway_integration.allarmi_options,
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name
  tags          = local.common_tags
}

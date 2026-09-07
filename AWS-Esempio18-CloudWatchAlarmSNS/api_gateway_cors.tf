# ====================================
# CORS - metodo OPTIONS per il preflight del browser
#
# La pagina web e' servita da Apache sull'istanza EC2 mentre l'API sta su un
# altro dominio (execute-api): senza CORS il browser blocca la chiamata.
# Gli header delle risposte reali sono aggiunti dalla Lambda (utils.api_response).
# ====================================

locals {
  cors_allow_origin  = "'${var.cors_allowed_origin}'"
  cors_allow_headers = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key,X-Amz-Security-Token'"
}

resource "aws_api_gateway_method" "allarmi_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.allarmi.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "allarmi_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.allarmi.id
  http_method = aws_api_gateway_method.allarmi_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "allarmi_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.allarmi.id
  http_method = aws_api_gateway_method.allarmi_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "allarmi_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.allarmi.id
  http_method = aws_api_gateway_method.allarmi_options.http_method
  status_code = aws_api_gateway_method_response.allarmi_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_allow_origin
    "method.response.header.Access-Control-Allow-Headers" = local.cors_allow_headers
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }

  depends_on = [aws_api_gateway_integration.allarmi_options]
}

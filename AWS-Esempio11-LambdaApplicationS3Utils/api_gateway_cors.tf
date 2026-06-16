# ====================================
# CORS — Metodi OPTIONS per preflight browser
# Ogni resource esposta via API Gateway necessita di un metodo OPTIONS
# che risponda con gli header Access-Control-Allow-* corretti.
# ====================================

locals {
  cors_headers = {
    "Access-Control-Allow-Origin"  = "'*'"
    "Access-Control-Allow-Headers" = "'Content-Type,Authorization,X-Amz-Date,X-Api-Key'"
    "Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
  }
}

# ---- /presigned-url OPTIONS ----
resource "aws_api_gateway_method" "presigned_url_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.presigned_url.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "presigned_url_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.presigned_url.id
  http_method = aws_api_gateway_method.presigned_url_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "presigned_url_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.presigned_url.id
  http_method = aws_api_gateway_method.presigned_url_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "presigned_url_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.presigned_url.id
  http_method = aws_api_gateway_method.presigned_url_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.presigned_url_options]
}

# ---- /extract-zip OPTIONS ----
resource "aws_api_gateway_method" "extract_zip_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.extract_zip.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "extract_zip_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.extract_zip.id
  http_method = aws_api_gateway_method.extract_zip_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "extract_zip_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.extract_zip.id
  http_method = aws_api_gateway_method.extract_zip_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "extract_zip_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.extract_zip.id
  http_method = aws_api_gateway_method.extract_zip_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.extract_zip_options]
}

# ---- /excel-to-csv OPTIONS ----
resource "aws_api_gateway_method" "excel_to_csv_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.excel_to_csv.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "excel_to_csv_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.excel_to_csv.id
  http_method = aws_api_gateway_method.excel_to_csv_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "excel_to_csv_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.excel_to_csv.id
  http_method = aws_api_gateway_method.excel_to_csv_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "excel_to_csv_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.excel_to_csv.id
  http_method = aws_api_gateway_method.excel_to_csv_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.excel_to_csv_options]
}

# ---- /upload-to-rds OPTIONS ----
resource "aws_api_gateway_method" "upload_to_rds_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload_to_rds.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_to_rds_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.upload_to_rds.id
  http_method = aws_api_gateway_method.upload_to_rds_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "upload_to_rds_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.upload_to_rds.id
  http_method = aws_api_gateway_method.upload_to_rds_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "upload_to_rds_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.upload_to_rds.id
  http_method = aws_api_gateway_method.upload_to_rds_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.upload_to_rds_options]
}

# ---- /sftp-send OPTIONS ----
resource "aws_api_gateway_method" "sftp_send_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.sftp_send.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "sftp_send_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.sftp_send.id
  http_method = aws_api_gateway_method.sftp_send_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "sftp_send_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.sftp_send.id
  http_method = aws_api_gateway_method.sftp_send_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "sftp_send_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.sftp_send.id
  http_method = aws_api_gateway_method.sftp_send_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.sftp_send_options]
}

# ---- /files OPTIONS ----
resource "aws_api_gateway_method" "files_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "files_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files.id
  http_method = aws_api_gateway_method.files_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "files_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files.id
  http_method = aws_api_gateway_method.files_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "files_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files.id
  http_method = aws_api_gateway_method.files_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.files_options]
}

# ---- /files/search OPTIONS ----
resource "aws_api_gateway_method" "files_search_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.files_search.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "files_search_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files_search.id
  http_method = aws_api_gateway_method.files_search_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "files_search_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files_search.id
  http_method = aws_api_gateway_method.files_search_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "files_search_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.files_search.id
  http_method = aws_api_gateway_method.files_search_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.files_search_options]
}

# ---- /read-from-rds OPTIONS ----
resource "aws_api_gateway_method" "read_from_rds_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.read_from_rds.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "read_from_rds_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.read_from_rds.id
  http_method = aws_api_gateway_method.read_from_rds_options.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "read_from_rds_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.read_from_rds.id
  http_method = aws_api_gateway_method.read_from_rds_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }
}

resource "aws_api_gateway_integration_response" "read_from_rds_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.read_from_rds.id
  http_method = aws_api_gateway_method.read_from_rds_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers["Access-Control-Allow-Origin"]
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers["Access-Control-Allow-Headers"]
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }
  depends_on = [aws_api_gateway_integration.read_from_rds_options]
}

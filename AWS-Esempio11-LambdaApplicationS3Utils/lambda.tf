# ====================================
# ARCHIVI ZIP LAMBDA
# Ogni archivio include il file principale + utils.py (modulo condiviso)
# ====================================

data "archive_file" "presigned_url" {
  type        = "zip"
  output_path = "${path.module}/lambda_presigned_url.zip"
  source {
    content  = file("${path.module}/lambda_functions/presigned_url.py")
    filename = "presigned_url.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "extract_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_extract_zip.zip"
  source {
    content  = file("${path.module}/lambda_functions/extract_zip.py")
    filename = "extract_zip.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "excel_to_csv" {
  type        = "zip"
  output_path = "${path.module}/lambda_excel_to_csv.zip"
  source {
    content  = file("${path.module}/lambda_functions/excel_to_csv.py")
    filename = "excel_to_csv.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "upload_to_rds" {
  type        = "zip"
  output_path = "${path.module}/lambda_upload_to_rds.zip"
  source {
    content  = file("${path.module}/lambda_functions/upload_to_rds.py")
    filename = "upload_to_rds.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "read_from_rds" {
  type        = "zip"
  output_path = "${path.module}/lambda_read_from_rds.zip"
  source {
    content  = file("${path.module}/lambda_functions/read_from_rds.py")
    filename = "read_from_rds.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "sftp_send" {
  type        = "zip"
  output_path = "${path.module}/lambda_sftp_send.zip"
  source {
    content  = file("${path.module}/lambda_functions/sftp_send.py")
    filename = "sftp_send.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "s3_scan" {
  type        = "zip"
  output_path = "${path.module}/lambda_s3_scan.zip"
  source {
    content  = file("${path.module}/lambda_functions/s3_scan.py")
    filename = "s3_scan.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "list_files" {
  type        = "zip"
  output_path = "${path.module}/lambda_list_files.zip"
  source {
    content  = file("${path.module}/lambda_functions/list_files.py")
    filename = "list_files.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "search_files" {
  type        = "zip"
  output_path = "${path.module}/lambda_search_files.zip"
  source {
    content  = file("${path.module}/lambda_functions/search_files.py")
    filename = "search_files.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

# ====================================
# LAMBDA FUNCTIONS
# ====================================

# Lambda 1: Presigned URL per upload
resource "aws_lambda_function" "presigned_url" {
  filename         = data.archive_file.presigned_url.output_path
  function_name    = "${var.project_name}-presigned-url"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "presigned_url.lambda_handler"
  source_code_hash = data.archive_file.presigned_url.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      BUCKET_NAME         = aws_s3_bucket.main.id
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_presigned_url]
}

# Lambda 2: Extract ZIP
resource "aws_lambda_function" "extract_zip" {
  filename         = data.archive_file.extract_zip.output_path
  function_name    = "${var.project_name}-extract-zip"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "extract_zip.lambda_handler"
  source_code_hash = data.archive_file.extract_zip.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      BUCKET_NAME         = aws_s3_bucket.main.id
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_extract_zip]
}

# Lambda 3: Excel to CSV
# NOTA: richiede Lambda Layer con openpyxl. Specificare l'ARN in var.lambda_layer_arns_excel
resource "aws_lambda_function" "excel_to_csv" {
  filename         = data.archive_file.excel_to_csv.output_path
  function_name    = "${var.project_name}-excel-to-csv"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "excel_to_csv.lambda_handler"
  source_code_hash = data.archive_file.excel_to_csv.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  layers           = var.lambda_layer_arns_excel

  environment {
    variables = {
      BUCKET_NAME         = aws_s3_bucket.main.id
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_excel_to_csv]
}

# Lambda 4: Upload to RDS
# NOTA: richiede Lambda Layer con pymysql. Specificare l'ARN in var.lambda_layer_arns_rds
resource "aws_lambda_function" "upload_to_rds" {
  filename         = data.archive_file.upload_to_rds.output_path
  function_name    = "${var.project_name}-upload-to-rds"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "upload_to_rds.lambda_handler"
  source_code_hash = data.archive_file.upload_to_rds.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  layers           = var.lambda_layer_arns_rds

  vpc_config {
    subnet_ids         = var.create_rds ? data.aws_subnets.default.ids : []
    security_group_ids = var.create_rds ? [aws_security_group.lambda[0].id] : []
  }

  environment {
    variables = {
      BUCKET_NAME         = aws_s3_bucket.main.id
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
      DB_HOST             = var.create_rds ? aws_rds_cluster.main[0].endpoint : ""
      DB_USERNAME         = "admin"
      DB_PASSWORD         = var.create_rds ? random_password.rds_password[0].result : ""
      DB_DATABASE         = var.rds_database_name
      DB_PORT             = "3306"
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_upload_to_rds]
}

# Lambda 4b: Read from RDS
# NOTA: richiede Lambda Layer con pymysql. Specificare l'ARN in var.lambda_layer_arns_rds
resource "aws_lambda_function" "read_from_rds" {
  filename         = data.archive_file.read_from_rds.output_path
  function_name    = "${var.project_name}-read-from-rds"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "read_from_rds.lambda_handler"
  source_code_hash = data.archive_file.read_from_rds.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  layers           = var.lambda_layer_arns_rds

  vpc_config {
    subnet_ids         = var.create_rds ? data.aws_subnets.default.ids : []
    security_group_ids = var.create_rds ? [aws_security_group.lambda[0].id] : []
  }

  environment {
    variables = {
      BUCKET_NAME         = aws_s3_bucket.main.id
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
      DB_HOST             = var.create_rds ? aws_rds_cluster.main[0].endpoint : ""
      DB_USERNAME         = "admin"
      DB_PASSWORD         = var.create_rds ? random_password.rds_password[0].result : ""
      DB_DATABASE         = var.rds_database_name
      DB_PORT             = "3306"
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_read_from_rds]
}

# Lambda 5: SFTP Send
# NOTA: richiede Lambda Layer con paramiko. Specificare l'ARN in var.lambda_layer_arns_sftp
resource "aws_lambda_function" "sftp_send" {
  filename         = data.archive_file.sftp_send.output_path
  function_name    = "${var.project_name}-sftp-send"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "sftp_send.lambda_handler"
  source_code_hash = data.archive_file.sftp_send.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size
  layers           = var.lambda_layer_arns_sftp

  environment {
    variables = {
      BUCKET_NAME            = aws_s3_bucket.main.id
      DYNAMODB_LOGS_TABLE    = aws_dynamodb_table.logs.name
      SFTP_PRIVATE_KEY_PARAM = var.sftp_private_key_ssm_parameter
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_sftp_send]
}

# Lambda 6: S3 Scan (invocata da EventBridge)
resource "aws_lambda_function" "s3_scan" {
  filename         = data.archive_file.s3_scan.output_path
  function_name    = "${var.project_name}-s3-scan"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "s3_scan.lambda_handler"
  source_code_hash = data.archive_file.s3_scan.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = 512

  environment {
    variables = {
      BUCKET_NAME         = aws_s3_bucket.main.id
      DYNAMODB_SCAN_TABLE = aws_dynamodb_table.scan.name
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_s3_scan]
}

# Lambda 7: List Files API
resource "aws_lambda_function" "list_files" {
  filename         = data.archive_file.list_files.output_path
  function_name    = "${var.project_name}-list-files"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "list_files.lambda_handler"
  source_code_hash = data.archive_file.list_files.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_SCAN_TABLE = aws_dynamodb_table.scan.name
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_list_files]
}

# Lambda 8: Search Files API
resource "aws_lambda_function" "search_files" {
  filename         = data.archive_file.search_files.output_path
  function_name    = "${var.project_name}-search-files"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "search_files.lambda_handler"
  source_code_hash = data.archive_file.search_files.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_SCAN_TABLE = aws_dynamodb_table.scan.name
      DYNAMODB_LOGS_TABLE = aws_dynamodb_table.logs.name
    }
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda_search_files]
}

# ====================================
# LAMBDA PERMISSIONS
# ====================================

# Permission per API Gateway
resource "aws_lambda_permission" "apigw_presigned_url" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_url.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_extract_zip" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.extract_zip.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_excel_to_csv" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.excel_to_csv.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_upload_to_rds" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_to_rds.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_sftp_send" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sftp_send.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_list_files" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_files.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_search_files" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_files.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_read_from_rds" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read_from_rds.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Permission per EventBridge
resource "aws_lambda_permission" "eventbridge_s3_scan" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_scan.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_scan_schedule.arn
}

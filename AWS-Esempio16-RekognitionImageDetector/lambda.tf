# ====================================
# ARCHIVI ZIP
# Ogni archivio contiene il modulo della funzione + utils.py (modulo condiviso)
# ====================================

data "archive_file" "detect_labels" {
  type        = "zip"
  output_path = "${path.module}/lambda_detect_labels.zip"
  source {
    content  = file("${path.module}/lambda_functions/detect_labels.py")
    filename = "detect_labels.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

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

data "archive_file" "list_images" {
  type        = "zip"
  output_path = "${path.module}/lambda_list_images.zip"
  source {
    content  = file("${path.module}/lambda_functions/list_images.py")
    filename = "list_images.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

# ====================================
# LAMBDA 1 - detect_labels
# Trigger: S3 ObjectCreated su input/
# Chiama Rekognition, salva le label su DynamoDB e valuta la parola chiave
# ====================================

resource "aws_lambda_function" "detect_labels" {
  function_name    = local.lambda_detect_labels_name
  filename         = data.archive_file.detect_labels.output_path
  source_code_hash = data.archive_file.detect_labels.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "detect_labels.lambda_handler"
  runtime          = "python3.11"
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.images.name
      KEYWORD        = var.keyword_rilevante
      MIN_CONFIDENCE = var.min_confidence
      MAX_LABELS     = var.max_labels
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_detect_labels]
  tags       = local.common_tags
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.detect_labels.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}

# ====================================
# LAMBDA 2 - presigned_url
# Trigger: POST /upload-url
# Genera un presigned URL PUT per caricare l'immagine direttamente da browser
# ====================================

resource "aws_lambda_function" "presigned_url" {
  function_name    = local.lambda_presigned_url_name
  filename         = data.archive_file.presigned_url.output_path
  source_code_hash = data.archive_file.presigned_url.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "presigned_url.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      BUCKET_NAME          = aws_s3_bucket.images.id
      INPUT_PREFIX         = var.input_prefix
      PRESIGNED_EXPIRATION = var.presigned_expiration
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_presigned_url]
  tags       = local.common_tags
}

# ====================================
# LAMBDA 3 - list_images
# Trigger: GET /images?rilevanti=true&limit=50
# Legge DynamoDB e aggiunge un presigned URL di anteprima per ogni immagine
# ====================================

resource "aws_lambda_function" "list_images" {
  function_name    = local.lambda_list_images_name
  filename         = data.archive_file.list_images.output_path
  source_code_hash = data.archive_file.list_images.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "list_images.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.images.name
      BUCKET_NAME    = aws_s3_bucket.images.id
      KEYWORD        = var.keyword_rilevante
      PREVIEW_EXPIRE = 300
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_list_images]
  tags       = local.common_tags
}

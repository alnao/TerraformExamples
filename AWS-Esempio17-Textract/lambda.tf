# ====================================
# ARCHIVI ZIP
# Ogni archivio contiene il modulo della funzione + i moduli condivisi
# ====================================

data "archive_file" "textract_analyze" {
  type        = "zip"
  output_path = "${path.module}/lambda_textract_analyze.zip"
  source {
    content  = file("${path.module}/lambda_functions/textract_analyze.py")
    filename = "textract_analyze.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/textract_parser.py")
    filename = "textract_parser.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

data "archive_file" "textract_collect" {
  type        = "zip"
  output_path = "${path.module}/lambda_textract_collect.zip"
  source {
    content  = file("${path.module}/lambda_functions/textract_collect.py")
    filename = "textract_collect.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/textract_parser.py")
    filename = "textract_parser.py"
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

data "archive_file" "list_documents" {
  type        = "zip"
  output_path = "${path.module}/lambda_list_documents.zip"
  source {
    content  = file("${path.module}/lambda_functions/list_documents.py")
    filename = "list_documents.py"
  }
  source {
    content  = file("${path.module}/lambda_functions/utils.py")
    filename = "utils.py"
  }
}

# I default Textract sono passati alle Lambda come JSON: la stessa forma che
# arriva dalla pagina web, cosi' il codice ha un solo formato da gestire.
locals {
  default_feature_types_json = jsonencode(var.default_feature_types)
  default_queries_json = jsonencode([
    for query in var.default_queries : {
      text  = query.text
      alias = query.alias
    }
  ])
}

# ====================================
# LAMBDA 1 - presigned_url
# Trigger: POST /upload-url
# Valida le opzioni Textract, le salva sotto jobs/ e restituisce il
# presigned URL PUT per caricare l'immagine direttamente da browser
# ====================================

resource "aws_lambda_function" "presigned_url" {
  function_name    = local.lambda_presigned_name
  filename         = data.archive_file.presigned_url.output_path
  source_code_hash = data.archive_file.presigned_url.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "presigned_url.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      BUCKET_NAME           = aws_s3_bucket.docs.id
      INPUT_PREFIX          = var.input_prefix
      JOBS_PREFIX           = var.jobs_prefix
      PRESIGNED_EXPIRATION  = var.presigned_expiration
      MAX_QUERIES           = var.max_queries
      AGGIUNGI_TIMESTAMP    = var.aggiungi_timestamp
      MAX_UPLOAD_MB         = var.max_upload_mb
      MAX_PDF_MB            = var.max_pdf_mb
      DEFAULT_FEATURE_TYPES = local.default_feature_types_json
      DEFAULT_QUERIES       = local.default_queries_json
      MIN_CONFIDENCE        = var.min_confidence
      SALVA_BLOCCHI_GREZZI  = var.salva_blocchi_grezzi
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_presigned]
  tags       = local.common_tags
}

# ====================================
# LAMBDA 2 - textract_analyze (via sincrona per le immagini,
#                              avvio del job asincrono per i PDF)
# Trigger: S3 ObjectCreated su input/ (invocazione ASINCRONA)
# Chiama Textract e salva il JSON con il testo estratto sotto output/
# ====================================

resource "aws_lambda_function" "textract_analyze" {
  function_name    = local.lambda_analyze_name
  filename         = data.archive_file.textract_analyze.output_path
  source_code_hash = data.archive_file.textract_analyze.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "textract_analyze.lambda_handler"
  runtime          = "python3.11"
  timeout          = var.lambda_analyze_timeout
  memory_size      = var.lambda_analyze_memory

  environment {
    variables = {
      INPUT_PREFIX          = var.input_prefix
      OUTPUT_PREFIX         = var.output_prefix
      RAW_PREFIX            = var.raw_prefix
      JOBS_PREFIX           = var.jobs_prefix
      MAX_QUERIES           = var.max_queries
      DEFAULT_FEATURE_TYPES = local.default_feature_types_json
      DEFAULT_QUERIES       = local.default_queries_json
      MIN_CONFIDENCE        = var.min_confidence
      SALVA_BLOCCHI_GREZZI  = var.salva_blocchi_grezzi
      SNS_TOPIC_ARN         = aws_sns_topic.textract.arn
      TEXTRACT_ROLE_ARN     = aws_iam_role.textract_sns.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_analyze]
  tags       = local.common_tags
}

# ====================================
# LAMBDA 3 - textract_collect
# Trigger: notifica SNS di fine job Textract (solo PDF)
# Scarica i blocchi con Get* seguendo i NextToken e sovrascrive il JSON
# provvisorio con quello definitivo
# ====================================

resource "aws_lambda_function" "textract_collect" {
  function_name    = local.lambda_collect_name
  filename         = data.archive_file.textract_collect.output_path
  source_code_hash = data.archive_file.textract_collect.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "textract_collect.lambda_handler"
  runtime          = "python3.11"
  timeout          = var.lambda_collect_timeout
  memory_size      = var.lambda_collect_memory

  environment {
    variables = {
      OUTPUT_PREFIX         = var.output_prefix
      RAW_PREFIX            = var.raw_prefix
      JOBS_PREFIX           = var.jobs_prefix
      MAX_QUERIES           = var.max_queries
      DEFAULT_FEATURE_TYPES = local.default_feature_types_json
      DEFAULT_QUERIES       = local.default_queries_json
      MIN_CONFIDENCE        = var.min_confidence
      SALVA_BLOCCHI_GREZZI  = var.salva_blocchi_grezzi
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_collect]
  tags       = local.common_tags
}

# Le invocazioni asincrone vengono ritentate fino a due volte in caso di
# errore: ogni retry e' pero' una nuova pagina fatturata da Textract, quindi
# il numero e' configurabile e di default resta basso.
resource "aws_lambda_function_event_invoke_config" "textract_analyze" {
  function_name                = aws_lambda_function.textract_analyze.function_name
  maximum_retry_attempts       = var.lambda_max_retry
  maximum_event_age_in_seconds = 3600
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_analyze.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.docs.arn
}

# ====================================
# LAMBDA 4 - list_documents
# Trigger: GET /documents?limit=50&stato=completati&q=...
# Unisce le immagini di input/ con i JSON di output/ e firma le anteprime
# ====================================

resource "aws_lambda_function" "list_documents" {
  function_name    = local.lambda_list_name
  filename         = data.archive_file.list_documents.output_path
  source_code_hash = data.archive_file.list_documents.output_base64sha256
  role             = aws_iam_role.lambda.arn
  handler          = "list_documents.lambda_handler"
  runtime          = "python3.11"
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      BUCKET_NAME    = aws_s3_bucket.docs.id
      INPUT_PREFIX   = var.input_prefix
      OUTPUT_PREFIX  = var.output_prefix
      PREVIEW_EXPIRE = var.preview_expiration
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_list]
  tags       = local.common_tags
}

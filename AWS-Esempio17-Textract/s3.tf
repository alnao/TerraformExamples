# ====================================
# S3 - BUCKET DEI DOCUMENTI
#
# Un solo bucket privato con tre aree logiche:
#   input/       immagini e PDF caricati dal browser con presigned URL PUT
#   output/      un JSON per documento con il testo estratto da Textract
#   output-raw/  risposta completa di Textract (solo se richiesta nell'upload)
#   jobs/        opzioni Textract scelte dall'utente al momento dell'upload
#
# Il browser non legge mai il bucket in chiaro: anteprime e download del JSON
# passano sempre da presigned URL generati dalla lambda list_documents.
# ====================================

resource "aws_s3_bucket" "docs" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket = aws_s3_bucket.docs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS: indispensabile per il PUT diretto dal browser verso il presigned URL
# e per mostrare le anteprime lette con presigned GET.
resource "aws_s3_bucket_cors_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# I file di opzioni servono solo fra la richiesta del presigned URL e
# l'analisi: dopo qualche giorno sono spazzatura e vengono cancellati.
resource "aws_s3_bucket_lifecycle_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    id     = "scadenza-file-opzioni"
    status = "Enabled"

    filter {
      prefix = var.jobs_prefix
    }

    expiration {
      days = var.jobs_expiration_days
    }
  }
}

# ====================================
# TRIGGER ASINCRONO
# Ogni file caricato sotto input/ invoca (in modo asincrono) la lambda di
# analisi. Si filtra per suffisso perche' le notifiche S3 non supportano i
# wildcard: serve una regola per estensione.
#
# Attenzione: il confronto sul suffisso e' CASE-SENSITIVE, quindi un file
# caricato come "Scansione.PDF" non farebbe scattare nulla. Per questo la
# lambda presigned_url mette sempre l'estensione in minuscolo nella key.
# ====================================

resource "aws_s3_bucket_notification" "docs" {
  bucket = aws_s3_bucket.docs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_analyze.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.input_prefix
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_analyze.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.input_prefix
    filter_suffix       = ".jpeg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_analyze.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.input_prefix
    filter_suffix       = ".png"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.textract_analyze.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.input_prefix
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

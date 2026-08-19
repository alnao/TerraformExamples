# ====================================
# S3 - BUCKET DELLE IMMAGINI
# Bucket privato: le immagini si caricano con presigned URL e si leggono
# con presigned URL generati dalla lambda list_images.
# ====================================

resource "aws_s3_bucket" "images" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = local.common_tags
}

# Nessun accesso pubblico: il browser usa sempre URL firmati
resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS: indispensabile per il PUT diretto dal browser verso il presigned URL
# e per mostrare le anteprime lette con presigned GET.
resource "aws_s3_bucket_cors_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Trigger: ogni immagine caricata sotto input/ invoca la lambda detect_labels.
# Rekognition DetectLabels accetta solo JPEG e PNG, quindi si filtra per suffisso.
resource "aws_s3_bucket_notification" "images" {
  bucket = aws_s3_bucket.images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.detect_labels.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.input_prefix
    filter_suffix       = ".jpg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.detect_labels.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.input_prefix
    filter_suffix       = ".jpeg"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.detect_labels.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.input_prefix
    filter_suffix       = ".png"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

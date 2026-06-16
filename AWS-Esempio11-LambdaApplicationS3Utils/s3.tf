# ====================================
# S3 BUCKET
# ====================================

resource "aws_s3_bucket" "main" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy_bucket
  tags          = local.common_tags
}

# Block all public access (sicuro per default)
# Impostare var.s3_public_read = true solo se il bucket deve essere pubblico (es. hosting statico)
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = var.s3_public_read ? false : true
  block_public_policy     = var.s3_public_read ? false : true
  ignore_public_acls      = var.s3_public_read ? false : true
  restrict_public_buckets = var.s3_public_read ? false : true
}

# Bucket Policy pubblica — creata solo se s3_public_read = true
resource "aws_s3_bucket_policy" "main" {
  count  = var.s3_public_read ? 1 : 0
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowPublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# Versioning (opzionale ma consigliato)
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

# EventBridge notification
resource "aws_s3_bucket_notification" "main" {
  bucket      = aws_s3_bucket.main.id
  eventbridge = true
}

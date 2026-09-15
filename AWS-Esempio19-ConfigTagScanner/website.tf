# ====================================
# S3 - SITO STATICO CON IL CRUSCOTTO DELLA CONFORMITA'
# Bucket pubblico in sola lettura, come AWS-Esempio03-WebSiteS3.
# ====================================

resource "aws_s3_bucket" "website" {
  bucket        = local.website_bucket_name
  force_destroy = var.force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website.arn}/*"
    }]
  })
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  source       = "${path.module}/website/index.html"
  etag         = filemd5("${path.module}/website/index.html")
  content_type = "text/html"
  tags         = local.common_tags
}

# config.js viene generato da Terraform con l'URL reale dello stage API:
# la pagina non contiene nessun endpoint scritto a mano.
locals {
  website_config_js = templatefile("${path.module}/website/config.js.tpl", {
    api_base_url = aws_api_gateway_stage.main.invoke_url
    rule_names   = jsonencode(local.rule_names)
    regions      = jsonencode(var.regions)
  })
}

resource "aws_s3_object" "config_js" {
  bucket       = aws_s3_bucket.website.id
  key          = "config.js"
  content      = local.website_config_js
  etag         = md5(local.website_config_js)
  content_type = "application/javascript"
  tags         = local.common_tags
}

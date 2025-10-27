variable "region" {
  description = "AWS region where to create resources"
  type        = string
  default     = "eu-central-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "aws-esempio04-cloudfront"
}

variable "force_destroy" {
  description = "Force destroy bucket even if not empty"
  type        = bool
  default     = true
}

variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

# CloudFront configuration
variable "cloudfront_comment" {
  description = "Comment for the CloudFront distribution"
  type        = string
  default     = "CloudFront distribution managed by Terraform"
}

variable "default_root_object" {
  description = "Default root object"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "Price class for CloudFront (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100" # USA, Europa, Israele
  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "price_class must be one of: PriceClass_All, PriceClass_200, PriceClass_100"
  }
}

variable "enable_ipv6" {
  description = "Enable IPv6"
  type        = bool
  default     = true
}

variable "domain_names" {
  description = "Alternate domain names (CNAMEs)"
  type        = list(string)
  default     = []
}

# Cache behavior
variable "viewer_protocol_policy" {
  description = "Viewer protocol policy (allow-all, https-only, redirect-to-https)"
  type        = string
  default     = "redirect-to-https"
}

variable "min_ttl" {
  description = "Minimum TTL in seconds"
  type        = number
  default     = 0
}

variable "default_ttl" {
  description = "Default TTL in seconds"
  type        = number
  default     = 3600 # 1 ora
}

variable "max_ttl" {
  description = "Maximum TTL in seconds"
  type        = number
  default     = 86400 # 24 ore
}

variable "enable_compression" {
  description = "Enable automatic compression"
  type        = bool
  default     = true
}

variable "forward_query_string" {
  description = "Forward query strings to origin"
  type        = bool
  default     = false
}

variable "forward_headers" {
  description = "Headers to forward to origin"
  type        = list(string)
  default     = []
}

variable "enable_static_files_caching" {
  description = "Enable aggressive caching for static files"
  type        = bool
  default     = true
}

# SSL/TLS configuration
variable "acm_certificate_arn" {
  description = "ARN of ACM certificate for custom domain (must be in us-east-1)"
  type        = string
  default     = ""
}

variable "minimum_protocol_version" {
  description = "Minimum TLS protocol version"
  type        = string
  default     = "TLSv1.2_2021"
}

# Geo restriction
variable "geo_restriction_type" {
  description = "Geo restriction type (none, whitelist, blacklist)"
  type        = string
  default     = "none"
}

variable "geo_restriction_locations" {
  description = "Country codes for geo restriction"
  type        = list(string)
  default     = []
}

# Error responses
variable "custom_error_responses" {
  description = "Custom error responses"
  type = list(object({
    error_code            = number
    response_code         = optional(number)
    response_page_path    = optional(string)
    error_caching_min_ttl = optional(number)
  }))
  default = [
    {
      error_code         = 404
      response_code      = 404
      response_page_path = "/error.html"
    },
    {
      error_code         = 403
      response_code      = 403
      response_page_path = "/error.html"
    }
  ]
}

# WAF
variable "web_acl_id" {
  description = "WAF Web ACL ID"
  type        = string
  default     = ""
}

# Logging
variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

# Functions
variable "cloudfront_function_arn" {
  description = "ARN of CloudFront function to associate"
  type        = string
  default     = ""
}

variable "create_url_rewrite_function" {
  description = "Create URL rewrite function for SPA"
  type        = bool
  default     = false
}

# Content
variable "index_html_content" {
  description = "Content of index.html"
  type        = string
  default     = <<-EOF
    <!DOCTYPE html>
    <html lang="it">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>CloudFront Distribution</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 900px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #232526 0%, #414345 100%);
                color: white;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
            }
            h1 { font-size: 2.5em; margin-bottom: 20px; }
            .badge { 
                background: #FF9900; 
                padding: 8px 20px; 
                border-radius: 5px; 
                display: inline-block; 
                margin: 10px 0;
                font-weight: bold;
            }
            .feature { 
                background: rgba(255, 255, 255, 0.05);
                padding: 15px;
                margin: 10px 0;
                border-radius: 5px;
                border-left: 4px solid #FF9900;
            }
            ul { list-style: none; padding: 0; }
            li { padding: 5px 0; }
            li:before { content: "⚡ "; color: #FF9900; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 AWS CloudFront Distribution</h1>
            <div class="badge">AWS Esempio 04</div>
            <p>Questo sito è servito tramite Amazon CloudFront CDN!</p>
            
            <div class="feature">
                <h3>✅ Caratteristiche CloudFront:</h3>
                <ul>
                    <li>Content Delivery Network globale</li>
                    <li>HTTPS/TLS automatico</li>
                    <li>Compressione Gzip automatica</li>
                    <li>Caching intelligente</li>
                    <li>Origin Access Control (OAC)</li>
                    <li>Custom error pages</li>
                    <li>Geo-restriction opzionale</li>
                    <li>WAF integration opzionale</li>
                </ul>
            </div>
            
            <div class="feature">
                <h3>📊 Performance:</h3>
                <ul>
                    <li>Latenza ridotta con edge locations</li>
                    <li>Cache distribuita globalmente</li>
                    <li>HTTP/2 e HTTP/3 supportati</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
  EOF
}

variable "error_html_content" {
  description = "Content of error.html"
  type        = string
  default     = <<-EOF
    <!DOCTYPE html>
    <html lang="it">
    <head>
        <meta charset="UTF-8">
        <title>Errore</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                text-align: center;
                padding: 50px;
                background: #232526;
                color: white;
            }
            h1 { font-size: 3em; color: #FF9900; }
        </style>
    </head>
    <body>
        <h1>Errore</h1>
        <p>La pagina richiesta non è disponibile.</p>
        <a href="/" style="color: #FF9900;">← Torna alla home</a>
    </body>
    </html>
  EOF
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio04CloudFront"
    CreatedBy   = "Terraform"
  }
}

variable "region" {
  description = "AWS region where to create resources"
  type        = string
  default     = "eu-central-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for website hosting"
  type        = string
  default     = "aws-esempio03-website"
}

variable "force_destroy" {
  description = "Force destroy bucket even if not empty"
  type        = bool
  default     = true
}

variable "index_document" {
  description = "Index document for the website"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document for the website"
  type        = string
  default     = "error.html"
}

variable "index_html_content" {
  description = "Content of index.html"
  type        = string
  default     = <<-EOF
    <!DOCTYPE html>
    <html lang="it">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Benvenuto - AWS S3 Static Website</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
            }
            h1 { font-size: 2.5em; margin-bottom: 20px; }
            p { font-size: 1.2em; line-height: 1.6; }
            .badge { 
                background: #FF9900; 
                padding: 5px 15px; 
                border-radius: 5px; 
                display: inline-block; 
                margin: 10px 0;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Sito Web Statico su AWS S3</h1>
            <div class="badge">AWS Esempio 03</div>
            <p>Questo è un sito web statico hostato su Amazon S3 e creato con Terraform.</p>
            <p>✅ Configurazione completata con successo!</p>
            <p><strong>Caratteristiche:</strong></p>
            <ul>
                <li>Hosting statico su S3</li>
                <li>Accesso pubblico configurato</li>
                <li>Versioning abilitato</li>
                <li>Gestito con Terraform</li>
            </ul>
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
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Errore 404</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
                color: white;
                text-align: center;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 10px;
            }
            h1 { font-size: 3em; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>404</h1>
            <h2>Pagina non trovata</h2>
            <p>La pagina che stai cercando non esiste.</p>
            <a href="/" style="color: white;">← Torna alla home</a>
        </div>
    </body>
    </html>
  EOF
}

variable "website_files" {
  description = "Additional files to upload to the website"
  type = map(object({
    source       = string
    content_type = string
  }))
  default = {}
}

variable "versioning_enabled" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable access logging"
  type        = bool
  default     = false
}

variable "enable_cors" {
  description = "Enable CORS configuration"
  type        = bool
  default     = true
}

variable "cors_allowed_headers" {
  description = "CORS allowed headers"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "CORS allowed methods"
  type        = list(string)
  default     = ["GET", "HEAD"]
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "CORS expose headers"
  type        = list(string)
  default     = ["ETag"]
}

variable "cors_max_age_seconds" {
  description = "CORS max age in seconds"
  type        = number
  default     = 3000
}

variable "routing_rules" {
  description = "Routing rules for the website"
  type = list(object({
    condition = map(string)
    redirect  = map(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio03WebSiteS3"
    CreatedBy   = "Terraform"
  }
}

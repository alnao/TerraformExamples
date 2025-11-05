# Resource Group variables
variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
  default     = "alnao-terraform-esempio03-websiteblob"
}

variable "location" {
  description = "Regione Azure"
  type        = string
  default     = "westeurope"
}

# Storage Account variables
variable "storage_account_name" {
  description = "Nome dello Storage Account (deve essere univoco globalmente)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Il nome deve essere lungo 3-24 caratteri e contenere solo lettere minuscole e numeri."
  }
  default     = "alnaoterraformes03web"
}

variable "account_tier" {
  description = "Tier dell'account storage"
  type        = string
  default     = "Standard"
}

variable "replication_type" {
  description = "Tipo di replica dello storage"
  type        = string
  default     = "LRS"
}

variable "min_tls_version" {
  description = "Versione minima di TLS"
  type        = string
  default     = "TLS1_2"
}

# Website configuration
variable "index_document" {
  description = "Index document per il sito web"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document per il sito web"
  type        = string
  default     = "error.html"
}

variable "index_html_content" {
  description = "Contenuto di index.html"
  type        = string
  default     = <<-EOF
    <!DOCTYPE html>
    <html lang="it">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Benvenuto - Azure Blob Storage Static Website</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #0078d4 0%, #00bcf2 100%);
                color: white;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
                backdrop-filter: blur(4px);
            }
            h1 { font-size: 2.5em; margin-bottom: 20px; }
            p { font-size: 1.2em; line-height: 1.6; }
            .badge { 
                background: #00bcf2; 
                padding: 5px 15px; 
                border-radius: 5px; 
                display: inline-block; 
                margin: 10px 0;
            }
            ul { list-style: none; padding: 0; }
            li { padding: 8px 0; padding-left: 25px; position: relative; }
            li:before { content: "✓ "; position: absolute; left: 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>☁️ Sito Web Statico su Azure Blob Storage</h1>
            <div class="badge">Azure Esempio 03</div>
            <p>Questo è un sito web statico hostato su Azure Blob Storage e creato con Terraform.</p>
            <p>✅ Configurazione completata con successo!</p>
            <p><strong>Caratteristiche:</strong></p>
            <ul>
                <li>Hosting statico su Blob Storage</li>
                <li>Accesso pubblico configurato</li>
                <li>Versioning opzionale</li>
                <li>CORS configurato</li>
                <li>Gestito con Terraform</li>
                <li>CDN opzionale per HTTPS</li>
            </ul>
        </div>
    </body>
    </html>
  EOF
}

variable "error_html_content" {
  description = "Contenuto di error.html"
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
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                max-width: 800px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #e74c3c 0%, #c0392b 100%);
                color: white;
                text-align: center;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 10px;
            }
            h1 { font-size: 3em; margin: 0; }
            h2 { font-size: 2em; }
            a { color: white; text-decoration: none; font-weight: bold; }
            a:hover { text-decoration: underline; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>404</h1>
            <h2>Pagina non trovata</h2>
            <p>La pagina che stai cercando non esiste su Azure Blob Storage.</p>
            <a href="/">← Torna alla home</a>
        </div>
    </body>
    </html>
  EOF
}

variable "website_files" {
  description = "File aggiuntivi da caricare"
  type = map(object({
    source       = string
    content_type = string
  }))
  default = {}
}

# Versioning and backup
variable "enable_versioning" {
  description = "Abilita versioning dei blob"
  type        = bool
  default     = true
}

variable "enable_soft_delete" {
  description = "Abilita soft delete"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Giorni di retention per soft delete"
  type        = number
  default     = 7
}

# CORS configuration
variable "enable_cors" {
  description = "Abilita CORS"
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
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "cors_exposed_headers" {
  description = "CORS exposed headers"
  type        = list(string)
  default     = ["*"]
}

variable "cors_max_age_seconds" {
  description = "CORS max age in seconds"
  type        = number
  default     = 3600
}

# CDN configuration
variable "enable_cdn" {
  description = "Abilita Azure CDN per HTTPS e performance"
  type        = bool
  default     = false
}

variable "cdn_sku" {
  description = "SKU del CDN (Standard_Microsoft, Standard_Akamai, Standard_Verizon, Premium_Verizon)"
  type        = string
  default     = "Standard_Microsoft"
}

variable "cdn_enable_compression" {
  description = "Abilita compressione sul CDN"
  type        = bool
  default     = true
}

variable "custom_domain_name" {
  description = "Nome del dominio personalizzato (es: www.example.com)"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tag da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio03WebsiteBlob"
    CreatedBy   = "Terraform"
  }
}

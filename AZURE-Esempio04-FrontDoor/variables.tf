# Resource Group variables
variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
  default     = "alnao-terraform-esempio04-frontdoor"
}

variable "location" {
  description = "Regione Azure"
  type        = string
  default     = "westeurope"
}

# Storage Account variables
variable "storage_account_name" {
  description = "Nome dello Storage Account"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Nome deve essere 3-24 caratteri, solo minuscole e numeri."
  }
}

variable "index_document" {
  description = "Index document"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document"
  type        = string
  default     = "error.html"
}

# Front Door variables
variable "frontdoor_name" {
  description = "Nome del Front Door profile"
  type        = string
  default     = "afd-esempio04"
}

variable "frontdoor_sku" {
  description = "SKU di Azure Front Door (Standard_AzureFrontDoor o Premium_AzureFrontDoor)"
  type        = string
  default     = "Standard_AzureFrontDoor"
  validation {
    condition     = contains(["Standard_AzureFrontDoor", "Premium_AzureFrontDoor"], var.frontdoor_sku)
    error_message = "SKU deve essere Standard_AzureFrontDoor o Premium_AzureFrontDoor."
  }
}

# Protocol configuration
variable "supported_protocols" {
  description = "Protocolli supportati"
  type        = list(string)
  default     = ["Http", "Https"]
}

variable "https_redirect_enabled" {
  description = "Abilita redirect HTTP -> HTTPS"
  type        = bool
  default     = true
}

variable "minimum_tls_version" {
  description = "Versione minima TLS"
  type        = string
  default     = "TLS12"
}

# Health probe
variable "health_probe_interval" {
  description = "Intervallo health probe in secondi"
  type        = number
  default     = 120
}

variable "health_probe_path" {
  description = "Path per health probe"
  type        = string
  default     = "/"
}

# Caching
variable "enable_caching" {
  description = "Abilita caching"
  type        = bool
  default     = true
}

variable "enable_compression" {
  description = "Abilita compressione"
  type        = bool
  default     = true
}

variable "static_files_cache_duration" {
  description = "Durata cache per file statici"
  type        = string
  default     = "1.00:00:00" # 1 giorno
}

# Custom domain
variable "custom_domain_name" {
  description = "Nome dominio personalizzato (es: www.example.com)"
  type        = string
  default     = ""
}

variable "dns_zone_id" {
  description = "ID della DNS Zone Azure (richiesto per custom domain)"
  type        = string
  default     = ""
}

# WAF
variable "enable_waf" {
  description = "Abilita WAF (richiede Premium SKU)"
  type        = bool
  default     = false
}

variable "waf_mode" {
  description = "Modalità WAF (Prevention o Detection)"
  type        = string
  default     = "Prevention"
}

# Monitoring
variable "enable_diagnostic_settings" {
  description = "Abilita diagnostic settings"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "ID del Log Analytics Workspace"
  type        = string
  default     = ""
}

# Content
variable "index_html_content" {
  description = "Contenuto di index.html"
  type        = string
  default     = <<-EOF
    <!DOCTYPE html>
    <html lang="it">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Azure Front Door</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                max-width: 900px;
                margin: 50px auto;
                padding: 20px;
                background: linear-gradient(135deg, #0078d4 0%, #005a9e 100%);
                color: white;
            }
            .container {
                background: rgba(255, 255, 255, 0.1);
                padding: 40px;
                border-radius: 10px;
                box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.37);
                backdrop-filter: blur(4px);
            }
            h1 { font-size: 2.5em; margin-bottom: 20px; }
            .badge { 
                background: #00bcf2; 
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
                border-left: 4px solid #00bcf2;
            }
            ul { list-style: none; padding: 0; }
            li { padding: 5px 0; }
            li:before { content: "⚡ "; color: #00bcf2; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🚀 Azure Front Door</h1>
            <div class="badge">Azure Esempio 04</div>
            <p>Questo sito è servito tramite Azure Front Door CDN!</p>
            
            <div class="feature">
                <h3>✅ Caratteristiche Azure Front Door:</h3>
                <ul>
                    <li>Global Content Delivery Network</li>
                    <li>HTTPS automatico con certificati gestiti</li>
                    <li>Compressione automatica</li>
                    <li>Caching intelligente con Rules Engine</li>
                    <li>Health probes e failover</li>
                    <li>WAF integrato (Premium SKU)</li>
                    <li>DDoS protection</li>
                    <li>Anycast routing per bassa latenza</li>
                </ul>
            </div>
            
            <div class="feature">
                <h3>📊 Performance & Security:</h3>
                <ul>
                    <li>Split TCP per connessioni più veloci</li>
                    <li>Microsoft Global Network</li>
                    <li>Managed rules per OWASP Top 10</li>
                    <li>Bot protection</li>
                    <li>Geo-filtering</li>
                </ul>
            </div>
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
        <title>Errore</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                text-align: center;
                padding: 50px;
                background: #0078d4;
                color: white;
            }
            h1 { font-size: 3em; color: #00bcf2; }
        </style>
    </head>
    <body>
        <h1>Errore</h1>
        <p>La pagina richiesta non è disponibile.</p>
        <a href="/" style="color: #00bcf2;">← Torna alla home</a>
    </body>
    </html>
  EOF
}

# Tags
variable "tags" {
  description = "Tag da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio04FrontDoor"
    CreatedBy   = "Terraform"
  }
}

# ===================================================================================
# Variables — AZURE-Esempio09-CosmosMongo
# Equivalente Azure di variables.tf AWS-Esempio09 (DynamoDB)
# ===================================================================================

# ── Azure Core ──────────────────────────────────────────────────────────────────
# Nota: subscription_id non è una variabile Terraform.
# Il provider v4 la legge automaticamente dalla variabile d'ambiente ARM_SUBSCRIPTION_ID.
# Impostala una volta sola dopo az login:
#   export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
  default     = "alnao-terraform-esempio09-cosmosmongo"
}

variable "location" {
  description = "Regione Azure"
  type        = string
  default     = "westeurope"
}

# ── CosmosDB Mongo Cluster (≈ aws_dynamodb_table) ───────────────────────────────

variable "cosmosdb_account_name" {
  description = "Nome del Cosmos DB Mongo Cluster (univoco globalmente, 3-44 caratteri)"
  type        = string
  default     = "alnao-terraform-esempio09-cosmosmongo"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,44}$", var.cosmosdb_account_name))
    error_message = "Nome deve essere 3-44 caratteri, solo minuscole, numeri e trattini."
  }
}

variable "mongodb_version" {
  description = "Versione MongoDB (≈ billing_mode su DynamoDB)"
  type        = string
  default     = "5.0"
  validation {
    condition     = contains(["5.0", "6.0", "7.0"], var.mongodb_version)
    error_message = "Versione supportata: 5.0, 6.0, 7.0."
  }
}

variable "compute_tier" {
  description = "Compute tier del cluster: 'Free' (gratuito, max 1 per subscription) o 'M25','M30','M40','M50','M60','M80'"
  type        = string
  default     = "Free"
}

variable "high_availability_mode" {
  description = "Modalità alta disponibilità (≈ replica_regions su DynamoDB)"
  type        = string
  default     = "Disabled"
  validation {
    condition     = contains(["Disabled", "SameZone", "ZoneRedundantPreferred"], var.high_availability_mode)
    error_message = "Valori validi: Disabled, SameZone, ZoneRedundantPreferred."
  }
}

variable "storage_size_in_gb" {
  description = "Dimensione storage in GB (minimo 32)"
  type        = number
  default     = 32
}

variable "mongodb_database_name" {
  description = "Nome del database MongoDB"
  type        = string
  default     = "esempio09db"
}

variable "mongodb_collection_name" {
  description = "Nome della collection MongoDB principale"
  type        = string
  default     = "annotazioni"
}

variable "mongodb_blob_collection_name" {
  description = "Nome della collection MongoDB dove la Function salva i metadati blob (≈ DynamoDB table per Lambda)"
  type        = string
  default     = "blob_metadata"
}

# ── MongoDB Credentials ──────────────────────────────────────────────────────────

variable "mongodb_username" {
  description = "Username amministratore MongoDB"
  type        = string
  default     = "adminuser"
}

variable "mongodb_password" {
  description = "Password amministratore MongoDB"
  type        = string
  sensitive   = true
  default     = "YourSecurePassword123!" # Cambiare → vedere terraform.tfvars.example
}

# ── Change Feed (≈ DynamoDB Streams) ────────────────────────────────────────────

variable "enable_change_feed" {
  description = "Abilita il Change Feed di CosmosDB (equivalente a DynamoDB Streams)"
  type        = bool
  default     = false
}

# ── Network Configuration ────────────────────────────────────────────────────────

variable "enable_public_network_access" {
  description = "Abilita accesso alla rete pubblica (Enabled/Disabled)"
  type        = string
  default     = "Enabled"
  validation {
    condition     = contains(["Enabled", "Disabled"], var.enable_public_network_access)
    error_message = "Il valore deve essere 'Enabled' o 'Disabled'."
  }
}

variable "enable_firewall_rule" {
  description = "Abilita firewall rule per il proprio IP (via Azure CLI local-exec)"
  type        = bool
  default     = false
}

variable "my_ip_address" {
  description = "Indirizzo IP da autorizzare nella firewall rule (usa 'curl -s ifconfig.me')"
  type        = string
  default     = "0.0.0.0"
}

# ── Private Endpoint (opzionale) ─────────────────────────────────────────────────

variable "enable_private_endpoint" {
  description = "Abilita la creazione del Private Endpoint"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_name" {
  description = "Nome della subnet per il private endpoint"
  type        = string
  default     = ""
}

variable "virtual_network_name" {
  description = "Nome della Virtual Network"
  type        = string
  default     = ""
}

variable "network_resource_group_name" {
  description = "Nome del Resource Group contenente la Virtual Network"
  type        = string
  default     = ""
}

variable "private_dns_zone_name" {
  description = "Nome della Private DNS Zone"
  type        = string
  default     = "privatelink.mongocluster.cosmos.azure.com"
}

variable "dns_resource_group_name" {
  description = "Nome del Resource Group contenente la Private DNS Zone"
  type        = string
  default     = "alnao-terraform-es09-net"
}

# ── Azure Key Vault (bonus, non presente in AWS-Esempio09) ────────────────────────

variable "enable_key_vault" {
  description = "Abilita Azure Key Vault per salvare i secrets"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Nome del Key Vault (deve essere univoco globalmente, 3-24 caratteri)"
  type        = string
  default     = "alnao-terraform-es9-key"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "Nome Key Vault: 3-24 caratteri, inizia con lettera, solo lettere/numeri/trattini."
  }
}

# ── Blob Function Integration (≈ enable_s3_lambda_integration) ───────────────────

variable "enable_blob_function_integration" {
  description = "Abilita Storage Account + Azure Function App con Blob Trigger (≈ S3 + Lambda + EventBridge)"
  type        = bool
  default     = true
}

variable "storage_account_name" {
  description = "Nome dello Storage Account (3-24 caratteri, solo minuscole e numeri)"
  type        = string
  default     = "alnaoterrafes09func"
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Nome storage: 3-24 caratteri, solo minuscole e numeri (no trattini)."
  }
}

variable "function_app_name" {
  description = "Nome della Azure Function App"
  type        = string
  default     = "alnao-terraform-es09-func"
}

variable "enable_delete_tracking" {
  description = "Abilita container separato per tracciamento eliminazioni blob (≈ enable_delete_tracking su AWS)"
  type        = bool
  default     = false
}

# ── Application Insights (≈ CloudWatch Log Group) ────────────────────────────────

variable "enable_application_insights" {
  description = "Abilita Application Insights + Log Analytics per la Function App"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Giorni di retention dei log (≈ retention_in_days di CloudWatch)"
  type        = number
  default     = 7
}

# ── Event Grid (≈ DynamoDB Streams / EventBridge monitoring) ─────────────────────

variable "enable_event_grid" {
  description = "Abilita Event Grid System Topic per monitoraggio eventi blob (≈ DynamoDB Streams)"
  type        = bool
  default     = false
}

# ── Monitor Alerts (≈ aws_cloudwatch_metric_alarm) ───────────────────────────────

variable "enable_monitor_alerts" {
  description = "Abilita Azure Monitor Metric Alert per CosmosDB (≈ CloudWatch Alarms su AWS)"
  type        = bool
  default     = false
}

variable "monitor_alert_threshold" {
  description = "Soglia di richieste oltre la quale scatta l'alert (≈ threshold in CloudWatch)"
  type        = number
  default     = 10000
}

# ── Tags ─────────────────────────────────────────────────────────────────────────

variable "tags" {
  description = "Tag da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio09CosmosMongo"
    CreatedBy   = "Terraform"
  }
}

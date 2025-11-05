variable "resource_group_name" {
  description = "Nome del resource group"
  type        = string
  default     = "alnao-terraform-esempio05-functions"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

# Storage Accounts
variable "storage_account_name" {
  description = "Nome dello storage account per Function App"
  type        = string
  default     = "stfuncapp05"
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage replication type"
  type        = string
  default     = "LRS"
}

variable "test_storage_account_name" {
  description = "Nome dello storage account per testing"
  type        = string
  default     = "sttest05"
}

variable "test_container_name" {
  description = "Nome del container per testing"
  type        = string
  default     = "testdata"
}

# Function App
variable "function_app_name" {
  description = "Nome della Function App"
  type        = string
  default     = "alnao-terraform-esempio05-functions"
}

variable "os_type" {
  description = "OS type (Linux o Windows)"
  type        = string
  default     = "Linux"

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type deve essere Linux o Windows"
  }
}

variable "sku_name" {
  description = "SKU del Service Plan (Y1=Consumption, B1=Basic, P1V2=Premium)"
  type        = string
  default     = "Y1"
}

variable "python_version" {
  description = "Versione Python"
  type        = string
  default     = "3.11"
}

variable "always_on" {
  description = "Always On (non disponibile per Consumption)"
  type        = bool
  default     = false
}

# Application Insights
variable "appinsights_retention_days" {
  description = "Giorni di retention per Application Insights"
  type        = number
  default     = 30
}

# CORS
variable "cors_allowed_origins" {
  description = "Origins ammessi per CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_support_credentials" {
  description = "Support credentials per CORS"
  type        = bool
  default     = false
}

# App Settings
variable "app_settings" {
  description = "App settings aggiuntive"
  type        = map(string)
  default     = {}
}

# Managed Identity
variable "enable_managed_identity" {
  description = "Abilita System Assigned Managed Identity"
  type        = bool
  default     = true
}

# Function Code
# Note: Il codice Python è ora separato nei file:
# - __init__.py: Codice principale della function
# - function.json: Configurazione binding
# - host.json: Configurazione runtime
# - requirements.txt: Dipendenze Python

variable "auto_deploy_function" {
  description = "Auto deploy della function (solo per demo)"
  type        = bool
  default     = true
}

# Metric Alerts
variable "enable_metric_alerts" {
  description = "Abilita metric alerts"
  type        = bool
  default     = false
}

variable "error_alert_threshold" {
  description = "Threshold per alert errori (HTTP 5xx)"
  type        = number
  default     = 5
}

variable "response_time_alert_threshold" {
  description = "Threshold per alert response time (secondi, 0=disabilitato)"
  type        = number
  default     = 0
}

variable "action_group_id" {
  description = "ID dell'Action Group per gli alert"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tags da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio05Functions"
    CreatedBy   = "Terraform"
  }
}

variable "resource_group_name" {
  description = "Nome del resource group"
  type        = string
  default     = "alnao-terraform-esempio06-eventgrid"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

variable "source_storage_account_name" {
  description = "Nome dello storage account sorgente"
  type        = string
  default     = "stsource06"
}

variable "source_container_name" {
  description = "Nome del container sorgente"
  type        = string
  default     = "sourcedata"
}

variable "function_storage_account_name" {
  description = "Nome dello storage account per Function"
  type        = string
  default     = "stfunc06"
}

variable "function_app_name" {
  description = "Nome della Function App"
  type        = string
  default     = "func-eventgrid-06"
}

variable "function_name" {
  description = "Nome della function da triggerare"
  type        = string
  default     = "BlobEventProcessor"
}

variable "sku_name" {
  description = "SKU del Service Plan"
  type        = string
  default     = "Y1"
}

variable "python_version" {
  description = "Versione Python"
  type        = string
  default     = "3.11"
}

variable "appinsights_retention_days" {
  description = "Retention giorni Application Insights"
  type        = number
  default     = 30
}

variable "app_settings" {
  description = "App settings aggiuntive"
  type        = map(string)
  default     = {}
}

variable "included_event_types" {
  description = "Tipi di eventi da includere"
  type        = list(string)
  default     = ["Microsoft.Storage.BlobCreated"]
}

variable "subject_begins_with" {
  description = "Subject begins with filter"
  type        = string
  default     = ""
}

variable "subject_ends_with" {
  description = "Subject ends with filter"
  type        = string
  default     = ""
}

variable "case_sensitive" {
  description = "Case sensitive filtering"
  type        = bool
  default     = false
}

variable "max_events_per_batch" {
  description = "Max events per batch"
  type        = number
  default     = 1
}

variable "preferred_batch_size_in_kilobytes" {
  description = "Preferred batch size in KB"
  type        = number
  default     = 64
}

variable "max_delivery_attempts" {
  description = "Max delivery attempts"
  type        = number
  default     = 30
}

variable "event_time_to_live" {
  description = "Event TTL in minuti"
  type        = number
  default     = 1440
}

variable "enable_dead_letter" {
  description = "Abilita dead letter destination"
  type        = bool
  default     = false
}

variable "dead_letter_container_name" {
  description = "Nome container dead letter"
  type        = string
  default     = "deadletter"
}

variable "subscription_labels" {
  description = "Labels per subscription"
  type        = list(string)
  default     = []
}

variable "enable_advanced_filter" {
  description = "Abilita advanced filter"
  type        = bool
  default     = false
}

variable "advanced_filter_string_contains" {
  description = "Advanced filter string contains"
  type = list(object({
    key    = string
    values = list(string)
  }))
  default = []
}

variable "enable_metric_alerts" {
  description = "Abilita metric alerts"
  type        = bool
  default     = false
}

variable "error_alert_threshold" {
  description = "Threshold alert errori"
  type        = number
  default     = 5
}

variable "action_group_id" {
  description = "ID Action Group per alert"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio06EventGrid"
    CreatedBy   = "Terraform"
  }
}

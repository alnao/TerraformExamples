# Resource Group variables
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

# CosmosDB Account variables
variable "cosmosdb_account_name" {
  description = "Nome dell'account CosmosDB (univoco globalmente)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,44}$", var.cosmosdb_account_name))
    error_message = "Nome deve essere 3-44 caratteri, solo minuscole, numeri e trattini."
  }
}

variable "mongo_server_version" {
  description = "Versione del server MongoDB (3.6, 4.0, 4.2)"
  type        = string
  default     = "4.2"
}

# Serverless vs Provisioned
variable "enable_serverless" {
  description = "Abilita modalità serverless (non compatibile con autoscale)"
  type        = bool
  default     = false
}

# Consistency level
variable "consistency_level" {
  description = "Livello di consistency (Eventual, Session, BoundedStaleness, Strong, ConsistentPrefix)"
  type        = string
  default     = "Session"
  validation {
    condition     = contains(["Eventual", "Session", "BoundedStaleness", "Strong", "ConsistentPrefix"], var.consistency_level)
    error_message = "Consistency level non valido."
  }
}

variable "max_interval_in_seconds" {
  description = "Max interval per BoundedStaleness (5-86400)"
  type        = number
  default     = 10
}

variable "max_staleness_prefix" {
  description = "Max staleness prefix per BoundedStaleness (10-2147483647)"
  type        = number
  default     = 200
}

# Geo-replication
variable "secondary_locations" {
  description = "Regioni secondarie per geo-replication"
  type = list(object({
    location          = string
    failover_priority = number
    zone_redundant    = optional(bool, false)
  }))
  default = []
}

variable "enable_zone_redundancy" {
  description = "Abilita zone redundancy"
  type        = bool
  default     = false
}

variable "enable_automatic_failover" {
  description = "Abilita automatic failover"
  type        = bool
  default     = true
}

variable "enable_multiple_write_locations" {
  description = "Abilita multiple write locations (multi-master)"
  type        = bool
  default     = false
}

# Backup
variable "backup_type" {
  description = "Tipo di backup (Periodic o Continuous)"
  type        = string
  default     = "Periodic"
  validation {
    condition     = contains(["Periodic", "Continuous"], var.backup_type)
    error_message = "backup_type deve essere Periodic o Continuous."
  }
}

variable "backup_interval_in_minutes" {
  description = "Intervallo backup in minuti (60-1440)"
  type        = number
  default     = 240
}

variable "backup_retention_in_hours" {
  description = "Retention backup in ore (8-720)"
  type        = number
  default     = 168 # 7 giorni
}

variable "backup_storage_redundancy" {
  description = "Ridondanza storage backup (Geo, Local, Zone)"
  type        = string
  default     = "Geo"
}

# Network
variable "public_network_access_enabled" {
  description = "Abilita accesso rete pubblica"
  type        = bool
  default     = true
}

variable "enable_virtual_network_filter" {
  description = "Abilita filtro virtual network"
  type        = bool
  default     = false
}

variable "virtual_network_rules" {
  description = "Regole virtual network"
  type = list(object({
    subnet_id                            = string
    ignore_missing_vnet_service_endpoint = optional(bool, false)
  }))
  default = []
}

variable "ip_range_filter" {
  description = "IP range filter (formato CIDR)"
  type        = string
  default     = ""
}

# Private Endpoint
variable "enable_private_endpoint" {
  description = "Abilita private endpoint"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "ID della subnet per private endpoint"
  type        = string
  default     = ""
}

# Features
variable "enable_analytical_storage" {
  description = "Abilita analytical storage (Synapse Link)"
  type        = bool
  default     = false
}

variable "enable_free_tier" {
  description = "Abilita free tier (400 RU/s e 5GB gratis)"
  type        = bool
  default     = false
}

# Database
variable "database_name" {
  description = "Nome del database MongoDB"
  type        = string
  default     = "mydb"
}

variable "database_throughput" {
  description = "Throughput del database in RU/s (min 400, solo se non autoscale)"
  type        = number
  default     = 400
}

variable "enable_autoscale" {
  description = "Abilita autoscale per database"
  type        = bool
  default     = false
}

variable "autoscale_max_throughput" {
  description = "Max throughput per autoscale"
  type        = number
  default     = 4000
}

# Collections
variable "collections" {
  description = "Map di collections da creare"
  type = map(object({
    shard_key               = optional(string)
    throughput              = optional(number)
    enable_autoscale        = optional(bool, false)
    max_throughput          = optional(number)
    default_ttl_seconds     = optional(number, -1)
    analytical_storage_ttl  = optional(number, -1)
    indexes = optional(list(object({
      keys   = list(string)
      unique = optional(bool, false)
    })), [])
  }))
  default = {
    "users" = {
      shard_key = "userId"
      indexes = [
        {
          keys   = ["_id"]
          unique = true
        },
        {
          keys   = ["email"]
          unique = true
        }
      ]
    }
  }
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

# Tags
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

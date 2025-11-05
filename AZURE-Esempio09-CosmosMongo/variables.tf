# Resource Group variables
variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
  default     = "alnao-terraform-esempio09-cosmosmongo"
}

# Azure Subscription (opzionale, usa quella di default se non specificata)
variable "subscription_id" {
  description = "ID della Azure Subscription (opzionale, usa la default se non specificata)"
  type        = string
  default     = null
}

variable "location" {
  description = "Regione Azure"
  type        = string
  default     = "westeurope"
}

# CosmosDB Mongo Cluster variables
variable "cosmosdb_account_name" {
  description = "Nome del Cosmos DB Mongo Cluster (univoco globalmente)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,44}$", var.cosmosdb_account_name))
    error_message = "Nome deve essere 3-44 caratteri, solo minuscole, numeri e trattini."
  }
  default     = "alnao-terraform-esempio09-cosmosmongo"
}

variable "mongodb_database_name" {
  description = "Nome del database MongoDB da creare"
  type        = string
  default     = "esempio09db"
}
variable "mongodb_collection_name" {
  description = "Nome della collection MongoDB da creare"
  type        = string
  default     = "annotazioni"
}

# MongoDB Credentials
variable "mongodb_username" {
  description = "Username amministratore MongoDB"
  type        = string
  default     = "adminuser"
}

variable "mongodb_password" {
  description = "Password amministratore MongoDB"
  type        = string
  sensitive   = true
  default     = "YourSecurePassword123!" # Cambiare con una password sicura -> vedere terraform.tfvars.example
}

# Private Endpoint Network Configuration
variable "enable_public_network_access" {
  description = "Abilita accesso alla rete pubblica (Enabled/Disabled)"
  type        = string
  default     = "Enabled"
  validation {
    condition     = contains(["Enabled", "Disabled"], var.enable_public_network_access)
    error_message = "Il valore deve essere 'Enabled' o 'Disabled'."
  }
}

variable "enable_private_endpoint" {
  description = "Abilita la creazione del Private Endpoint (richiede VNet e DNS Zone esistenti)"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_name" {
  description = "Nome della subnet per il private endpoint (richiesto solo se enable_private_endpoint=true)"
  type        = string
  default     = ""
}

variable "virtual_network_name" {
  description = "Nome della Virtual Network contenente la subnet (richiesto solo se enable_private_endpoint=true)"
  type        = string
  default     = ""
}

variable "network_resource_group_name" {
  description = "Nome del Resource Group contenente la Virtual Network (richiesto solo se enable_private_endpoint=true)"
  type        = string
  default     = ""
}

variable "private_dns_zone_name" {
  description = "Nome della Private DNS Zone (richiesto solo se enable_private_endpoint=true)"
  type        = string
  default     = "privatelink.mongocluster.cosmos.azure.com"
}

variable "dns_resource_group_name" {
  description = "Nome del Resource Group contenente la Private DNS Zone (richiesto solo se enable_private_endpoint=true)"
  type        = string
  default     = "alnao-terraform-es09-net"
}

# Azure Key Vault Configuration
variable "enable_key_vault" {
  description = "Abilita la creazione di Azure Key Vault per salvare i secrets (connection string, username, password)"
  type        = bool
  default     = true
}

variable "key_vault_name" {
  description = "Nome del Key Vault (deve essere univoco globalmente, 3-24 caratteri)"
  type        = string
  default     = "alnao-terraform-es9-key"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.key_vault_name))
    error_message = "Nome Key Vault deve essere 3-24 caratteri, iniziare con lettera, contenere solo lettere, numeri e trattini."
  }
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

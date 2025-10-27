# Variabili per il Resource Group
variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
  default     = "alnao-terraform-esempio01"
}

variable "location" {
  description = "Regione Azure dove creare le risorse"
  type        = string
  default     = "westeurope"
}

# Variabili per lo Storage Account
variable "storage_account_name" {
  description = "Nome dello Storage Account (deve essere univoco globalmente)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Il nome dello storage account deve essere lungo 3-24 caratteri e contenere solo lettere minuscole e numeri."
  } 
  default    = "alnaoterraformesempio01"
}

variable "account_tier" {
  description = "Tier dell'account storage (Standard o Premium)"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "account_tier deve essere 'Standard' o 'Premium'."
  }
}

variable "replication_type" {
  description = "Tipo di replica dello storage (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "LRS"
  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type deve essere uno tra: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "account_kind" {
  description = "Tipo di account storage (BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2)"
  type        = string
  default     = "StorageV2"
  validation {
    condition     = contains(["BlobStorage", "BlockBlobStorage", "FileStorage", "Storage", "StorageV2"], var.account_kind)
    error_message = "account_kind deve essere uno tra: BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2."
  }
}

# Variabili di sicurezza
variable "min_tls_version" {
  description = "Versione minima di TLS"
  type        = string
  default     = "TLS1_2"
}

variable "allow_public_access" {
  description = "Consenti accesso pubblico ai blob"
  type        = bool
  default     = false
}

variable "public_network_access" {
  description = "Abilita l'accesso dalla rete pubblica"
  type        = bool
  default     = true
}

# Variabili per i container
variable "containers" {
  description = "Lista dei container da creare"
  type = list(object({
    name        = string
    access_type = string
  }))
  default = [
    {
      name        = "documents"
      access_type = "private"
    }
  ]
  validation {
    condition = alltrue([
      for container in var.containers : contains(["private", "blob", "container"], container.access_type)
    ])
    error_message = "access_type deve essere 'private', 'blob' o 'container'."
  }
}

# Variabili per il versioning e soft delete
variable "enable_versioning" {
  description = "Abilita il versioning dei blob"
  type        = bool
  default     = true
}

variable "enable_change_feed" {
  description = "Abilita il change feed"
  type        = bool
  default     = false
}

variable "change_feed_retention_days" {
  description = "Giorni di retention per il change feed"
  type        = number
  default     = 7
}

variable "enable_soft_delete" {
  description = "Abilita soft delete per i blob"
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Giorni di retention per soft delete dei blob"
  type        = number
  default     = 7
  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days deve essere tra 1 e 365."
  }
}

variable "enable_container_soft_delete" {
  description = "Abilita soft delete per i container"
  type        = bool
  default     = true
}

variable "container_soft_delete_retention_days" {
  description = "Giorni di retention per soft delete dei container"
  type        = number
  default     = 7
  validation {
    condition     = var.container_soft_delete_retention_days >= 1 && var.container_soft_delete_retention_days <= 365
    error_message = "container_soft_delete_retention_days deve essere tra 1 e 365."
  }
}

# Variabili per lifecycle policy
variable "enable_lifecycle_policy" {
  description = "Abilita la policy del ciclo di vita"
  type        = bool
  default     = false
}

variable "lifecycle_prefix_match" {
  description = "Prefisso per i blob da includere nella lifecycle policy"
  type        = list(string)
  default     = ["logs/"]
}

variable "lifecycle_cool_after_days" {
  description = "Giorni dopo i quali spostare i blob al tier Cool"
  type        = number
  default     = 30
}

variable "lifecycle_archive_after_days" {
  description = "Giorni dopo i quali spostare i blob al tier Archive"
  type        = number
  default     = 90
}

variable "lifecycle_delete_after_days" {
  description = "Giorni dopo i quali eliminare i blob"
  type        = number
  default     = 365
}

# Tags
variable "tags" {
  description = "Tag da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "terraform-examples"
    Owner       = "alnao"
    Purpose     = "storage-example"
  }
}

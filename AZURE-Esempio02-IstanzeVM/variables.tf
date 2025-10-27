# Resource Group variables
variable "resource_group_name" {
  description = "Nome del Resource Group"
  type        = string
  default     = "alnao-terraform-esempio02-vm"
}

variable "location" {
  description = "Regione Azure dove creare le risorse"
  type        = string
  default     = "westeurope"
}

# VM variables
variable "vm_name" {
  description = "Nome della Virtual Machine"
  type        = string
  default     = "azure-esempio02-vm"
}

variable "vm_size" {
  description = "Dimensione della VM (es: Standard_B2s, Standard_D2s_v3)"
  type        = string
  default     = "Standard_B2ms" # Standard_B1s non disponibile in germanywestcentral
}

variable "admin_username" {
  description = "Username amministratore della VM"
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Password amministratore (richiesta se disable_password_authentication è false)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "disable_password_authentication" {
  description = "Disabilita autenticazione con password (usa solo SSH key)"
  type        = bool
  default     = true
}

variable "ssh_public_key" {
  description = "Chiave pubblica SSH per l'accesso"
  type        = string
  default     = ""
}

# Network variables
variable "vnet_address_space" {
  description = "Address space della Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  description = "Address prefix della subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "create_public_ip" {
  description = "Crea un IP pubblico per la VM"
  type        = bool
  default     = true
}

variable "public_ip_allocation_method" {
  description = "Metodo di allocazione IP pubblico (Static o Dynamic)"
  type        = string
  default     = "Static"
}

variable "public_ip_sku" {
  description = "SKU dell'IP pubblico (Basic o Standard)"
  type        = string
  default     = "Standard"
}

# Security variables
variable "ssh_source_addresses" {
  description = "Indirizzi IP sorgente consentiti per SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ATTENZIONE: limitare in produzione!
}

variable "http_source_addresses" {
  description = "Indirizzi IP sorgente consentiti per HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_source_addresses" {
  description = "Indirizzi IP sorgente consentiti per HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# OS Disk variables
variable "os_disk_caching" {
  description = "Tipo di caching per OS disk (None, ReadOnly, ReadWrite)"
  type        = string
  default     = "ReadWrite"
}

variable "os_disk_storage_account_type" {
  description = "Tipo di storage per OS disk (Standard_LRS, StandardSSD_LRS, Premium_LRS)"
  type        = string
  default     = "Standard_LRS"
}

variable "os_disk_size_gb" {
  description = "Dimensione OS disk in GB"
  type        = number
  default     = 30
}

# Image variables
variable "image_publisher" {
  description = "Publisher dell'immagine"
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "Offer dell'immagine"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "SKU dell'immagine"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  description = "Versione dell'immagine"
  type        = string
  default     = "latest"
}

# Data disk variables
variable "create_data_disk" {
  description = "Crea un disco dati aggiuntivo"
  type        = bool
  default     = false
}

variable "data_disk_size_gb" {
  description = "Dimensione del disco dati in GB"
  type        = number
  default     = 50
}

variable "data_disk_storage_account_type" {
  description = "Tipo di storage per data disk"
  type        = string
  default     = "Standard_LRS"
}

# Custom data (cloud-init)
variable "custom_data" {
  description = "Script cloud-init da eseguire all'avvio"
  type        = string
  default     = ""
}

# Boot diagnostics
variable "enable_boot_diagnostics" {
  description = "Abilita boot diagnostics"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tag da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio02IstanzeVM"
    CreatedBy   = "Terraform"
  }
}

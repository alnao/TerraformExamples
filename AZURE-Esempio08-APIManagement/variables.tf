variable "resource_group_name" {
  default = "alnao-terraform-esempio08-apim"
}

variable "location" {
  default = "westeurope"
}

variable "storage_account_name" {
  default = "stfiles08"
}

variable "function_storage_name" {
  default = "stfunc08"
}

variable "function_app_name" {
  default = "func-api-08"
}

variable "apim_name" {
  default = "apim-esempio08"
}

variable "apim_sku" {
  description = "SKU (Consumption, Developer, Basic, Standard, Premium)"
  default     = "Consumption_0"
}

variable "publisher_name" {
  default = "alnao"
}

variable "publisher_email" {
  default = "admin@example.com"
}

variable "subscription_required" {
  default = false
}

variable "tags" {
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio08APIManagement"
    CreatedBy   = "Terraform"
  }
}

variable "resource_group_name" {
  default = "alnao-terraform-esempio07-logicapps"
}

variable "location" {
  default = "westeurope"
}

variable "source_storage_name" {
  default = "stsource07"
}

variable "destination_storage_name" {
  default = "stdest07"
}

variable "function_storage_name" {
  default = "stfunc07"
}

variable "logic_app_name" {
  default = "logic-copy-blob-07"
}

variable "function_app_name" {
  default = "func-logger-07"
}

variable "tags" {
  description = "Tag da applicare alle risorse"
  type        = map(string)
  default = {
    Name        = "azure-esempio07.logic-apps"
    Environment = "dev"
    Project     = "Development.azure.terraform07-LogicApps"
    Owner       = "AlNao"
    CostCenter  = "dev"
    ManagedBy   = "Terraform"
  }
}

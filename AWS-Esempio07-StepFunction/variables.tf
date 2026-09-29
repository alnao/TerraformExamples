variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "source_bucket_name" {
  description = "Nome bucket sorgente"
  type        = string
  default     = "alnao-dev-terraform-esempio07-step-source"
}

variable "destination_bucket_name" {
  description = "Nome bucket destinazione"
  type        = string
  default     = "alnao-dev-terraform-esempio07-step-dest"
}

variable "force_destroy" {
  description = "Force destroy buckets"
  type        = bool
  default     = true
}

variable "step_function_name" {
  description = "Nome Step Function"
  type        = string
  default     = "alnao-dev-terraform-esempio07-step-function"
}

variable "logger_function_name" {
  description = "Nome Lambda logger"
  type        = string
  default     = "alnao-dev-terraform-esempio07-step-function-logger"
}

variable "step_function_log_level" {
  description = "Log level (ALL, ERROR, FATAL, OFF)"
  type        = string
  default     = "ALL"
}

variable "enable_xray_tracing" {
  description = "Abilita X-Ray tracing"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention giorni log"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Name        = "aws-esempio07.step-function"
    Environment = "dev"
    Project     = "Development.aws.terraform07-StepFunction"
    Owner       = "AlNao"
    CostCenter  = "dev"
    ManagedBy   = "Terraform"
  }
}

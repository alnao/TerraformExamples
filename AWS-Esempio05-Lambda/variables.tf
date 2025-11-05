variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "bucket_name" {
  description = "Nome del bucket S3 per testing"
  type        = string
  default     = "alnao-terraform-aws-esempio05-lambda-bucket"
}

variable "force_destroy" {
  description = "Force destroy del bucket"
  type        = bool
  default     = true
}

# Lambda configuration
variable "lambda_function_name" {
  description = "Nome della Lambda function"
  type        = string
  default     = "alnao-terraform-aws-esempio05-lambda"
}

variable "lambda_runtime" {
  description = "Runtime della Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_handler" {
  description = "Handler della Lambda"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_timeout" {
  description = "Timeout in secondi"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size in MB"
  type        = number
  default     = 128
}

variable "lambda_environment_variables" {
  description = "Environment variables aggiuntive"
  type        = map(string)
  default     = {}
}

variable "lambda_layers" {
  description = "ARN dei Lambda layers"
  type        = list(string)
  default     = []
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrent executions (-1 per unlimited)"
  type        = number
  default     = -1
}

# VPC Configuration
variable "vpc_subnet_ids" {
  description = "Subnet IDs per VPC"
  type        = list(string)
  default     = []
}

variable "vpc_security_group_ids" {
  description = "Security Group IDs per VPC"
  type        = list(string)
  default     = []
}

# Dead Letter Queue
variable "dead_letter_queue_arn" {
  description = "ARN della DLQ"
  type        = string
  default     = ""
}

# Function URL
variable "enable_function_url" {
  description = "Abilita Function URL"
  type        = bool
  default     = true
}

variable "function_url_auth_type" {
  description = "Authorization type (NONE o AWS_IAM)"
  type        = string
  default     = "NONE"
}

# CORS for Function URL
variable "cors_allow_credentials" {
  description = "CORS allow credentials"
  type        = bool
  default     = false
}

variable "cors_allow_origins" {
  description = "CORS allowed origins"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "CORS allowed methods"
  type        = list(string)
  default     = ["GET", "POST"]
}

variable "cors_allow_headers" {
  description = "CORS allowed headers"
  type        = list(string)
  default     = ["*"]
}

variable "cors_expose_headers" {
  description = "CORS exposed headers"
  type        = list(string)
  default     = []
}

variable "cors_max_age" {
  description = "CORS max age"
  type        = number
  default     = 3600
}

# Alias
variable "create_alias" {
  description = "Crea alias per la function"
  type        = bool
  default     = false
}

variable "alias_name" {
  description = "Nome dell'alias"
  type        = string
  default     = "live"
}

variable "alias_function_version" {
  description = "Versione della function per l'alias"
  type        = string
  default     = "$LATEST"
}

# External invoke permission
variable "allow_external_invoke" {
  description = "Permetti invocazione esterna"
  type        = bool
  default     = false
}

variable "invoke_principal" {
  description = "Principal che può invocare la Lambda"
  type        = string
  default     = "apigateway.amazonaws.com"
}

variable "invoke_source_arn" {
  description = "Source ARN per l'invocazione"
  type        = string
  default     = ""
}

# Logging
variable "log_retention_days" {
  description = "Giorni di retention dei log"
  type        = number
  default     = 7
}

# CloudWatch Alarms
variable "enable_error_alarm" {
  description = "Abilita alarm per errori"
  type        = bool
  default     = false
}

variable "error_alarm_threshold" {
  description = "Threshold per alarm errori"
  type        = number
  default     = 5
}

variable "enable_throttle_alarm" {
  description = "Abilita alarm per throttling"
  type        = bool
  default     = false
}

variable "throttle_alarm_threshold" {
  description = "Threshold per alarm throttling"
  type        = number
  default     = 10
}

variable "alarm_actions" {
  description = "ARN per azioni alarm (SNS topics)"
  type        = list(string)
  default     = []
}

# Tags
variable "tags" {
  description = "Tags da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio05Lambda"
    CreatedBy   = "Terraform"
  }
}

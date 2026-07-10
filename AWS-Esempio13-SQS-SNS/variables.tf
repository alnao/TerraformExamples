variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefisso del progetto da utilizzare per i nomi delle risorse"
  type        = string
  default     = "alnao-dev-terraform-es13"
}

# Lambda configuration
variable "lambda_function_name" {
  description = "Nome della Lambda function"
  type        = string
  default     = "alnao-dev-terraform-es13-processor"
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
  description = "Timeout in secondi per la Lambda"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Dimensione memoria in MB per la Lambda"
  type        = number
  default     = 128
}

# DynamoDB Configuration
variable "dynamodb_table_name" {
  description = "Nome della tabella DynamoDB"
  type        = string
  default     = "alnao-dev-terraform-es13-logs"
}

variable "dynamodb_billing_mode" {
  description = "Billing mode per DynamoDB"
  type        = string
  default     = "PAY_PER_REQUEST"
}

# SQS Configuration
variable "sqs_queue_name" {
  description = "Nome della coda SQS"
  type        = string
  default     = "alnao-dev-terraform-es13-queue"
}

variable "sqs_message_retention_seconds" {
  description = "Tempo di retention dei messaggi in SQS (secondi)"
  type        = number
  default     = 86400 # 1 giorno
}

# SNS Configuration
variable "sns_topic_name" {
  description = "Nome del topic SNS"
  type        = string
  default     = "alnao-dev-terraform-es13-topic"
}

variable "notification_email" {
  description = "Email alla quale inviare le notifiche dei messaggi (lasciare vuoto per non configurare la subscription)"
  type        = string
  default     = ""
}

# Logging
variable "log_retention_days" {
  description = "Giorni di retention per i Log Group di CloudWatch"
  type        = number
  default     = 7
}

# Tags
variable "tags" {
  description = "Tags da applicare a tutte le risorse create"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio13SQSSNS"
    CreatedBy   = "Terraform"
  }
}

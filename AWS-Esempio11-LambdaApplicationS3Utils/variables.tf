variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Nome del progetto (usato per prefissi risorse)"
  type        = string
  default     = "esempio-11"
}

variable "environment" {
  description = "Ambiente (dev, prod, etc.)"
  type        = string
  default     = "dev"
}

# S3 Configuration
variable "bucket_name" {
  description = "Nome del bucket S3 principale"
  type        = string
  default     = "alnao-terraform-aws-esempio11-storage"
}

variable "force_destroy_bucket" {
  description = "Permetti distruzione bucket anche se non vuoto"
  type        = bool
  default     = true
}

# DynamoDB Configuration
variable "dynamodb_logs_table_name" {
  description = "Nome tabella DynamoDB per i log"
  type        = string
  default     = "esempio-11-logs"
}

variable "dynamodb_scan_suffix" {
  description = "Suffisso per tabella scan (formato: <project_name>-<suffix>)"
  type        = string
  default     = "scan"
}

variable "dynamodb_billing_mode" {
  description = "Billing mode per DynamoDB (PROVISIONED o PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

# RDS Configuration
variable "create_rds" {
  description = "Crea istanza RDS Aurora"
  type        = bool
  default     = true
}

variable "rds_engine" {
  description = "Engine RDS (aurora-mysql o aurora-postgresql)"
  type        = string
  default     = "aurora-mysql"
}

variable "rds_engine_version" {
  description = "Versione engine RDS"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "rds_instance_class" {
  description = "Classe istanza RDS"
  type        = string
  default     = "db.t3.small"
}

variable "rds_database_name" {
  description = "Nome database RDS"
  type        = string
  default     = "esempio11db"
}

# Lambda Configuration
variable "lambda_runtime" {
  description = "Runtime per le Lambda functions"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Timeout in secondi per le Lambda"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Memory size in MB per le Lambda"
  type        = number
  default     = 512
}

# API Gateway Configuration
variable "api_name" {
  description = "Nome API Gateway"
  type        = string
  default     = "esempio-11-api"
}

variable "api_stage_name" {
  description = "Nome dello stage API Gateway"
  type        = string
  default     = "v1"
}

# EventBridge Configuration
variable "enable_s3_scan_schedule" {
  description = "Abilita scansione S3 schedulata"
  type        = bool
  default     = true
}

variable "s3_scan_schedule_expression" {
  description = "Espressione cron per scansione S3 (default: giornaliera alle 02:00)"
  type        = string
  default     = "cron(0 2 * * ? *)"
}

# SFTP Configuration
variable "sftp_private_key_ssm_parameter" {
  description = "Nome del parametro SSM per la chiave privata SFTP (formato RSA)"
  type        = string
  default     = "/esempio-11/sftp/private-key"
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Giorni di retention per i log CloudWatch"
  type        = number
  default     = 7
}

variable "enable_cloudwatch_alarms" {
  description = "Abilita CloudWatch alarms"
  type        = bool
  default     = true
}

variable "lambda_error_threshold" {
  description = "Threshold errori Lambda per allarme"
  type        = number
  default     = 5
}

variable "api_4xx_threshold" {
  description = "Threshold errori 4XX API Gateway per allarme"
  type        = number
  default     = 10
}

variable "api_5xx_threshold" {
  description = "Threshold errori 5XX API Gateway per allarme"
  type        = number
  default     = 5
}

variable "alarm_email" {
  description = "Email per notifiche allarmi (vuoto per non creare SNS topic)"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tags da applicare a tutte le risorse"
  type        = map(string)
  default = {
    Environment = "dev"
    Owner       = "alnao"
    Example     = "Esempio11LambdaApplicationS3Utils"
    CreatedBy   = "Terraform"
  }
}

variable "additional_tags" {
  description = "Tags aggiuntivi specifici del progetto"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "cluster_identifier" {
  description = "Nome del cluster Aurora"
  type        = string
  default     = "alnao-terraform-aws-esempio10-aurora"
}

variable "engine" {
  description = "Database engine (aurora-mysql o aurora-postgresql)"
  type        = string
  default     = "aurora-mysql"
}

variable "engine_version" {
  description = "Versione del database engine"
  type        = string
  default     = "8.0.mysql_aurora.3.04.0"
}

variable "database_name" {
  description = "Nome del database"
  type        = string
  default     = "esempio10db"
}

variable "master_username" {
  description = "Username master del database"
  type        = string
  default     = "admin"
}

variable "master_password" {
  description = "Password master del database (usare Secrets Manager in produzione)"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "instance_class" {
  description = "Classe dell'istanza RDS (più piccola: db.t3.small)"
  type        = string
  default     = "db.t3.small"
}

variable "instance_count" {
  description = "Numero di istanze nel cluster"
  type        = number
  default     = 1
}

variable "backup_retention_period" {
  description = "Periodo di retention dei backup in giorni"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Finestra preferita per i backup"
  type        = string
  default     = "03:00-04:00"
}

variable "preferred_maintenance_window" {
  description = "Finestra preferita per la manutenzione"
  type        = string
  default     = "mon:04:00-mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Abilita protezione dalla cancellazione"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Rende il cluster accessibile pubblicamente"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks autorizzati per la connessione (0.0.0.0/0 per tutti)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "port" {
  description = "Porta del database"
  type        = number
  default     = 3306
}

variable "enable_http_endpoint" {
  description = "Abilita Data API HTTP endpoint"
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Abilita encryption dello storage"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS Key ID per encryption (vuoto per chiave AWS managed)"
  type        = string
  default     = ""
}

variable "enabled_cloudwatch_logs_exports" {
  description = "Log types da esportare su CloudWatch"
  type        = list(string)
  default     = ["audit", "error", "general", "slowquery"]
}

variable "log_retention_days" {
  description = "Giorni di retention dei log CloudWatch"
  type        = number
  default     = 7
}

variable "enable_performance_insights" {
  description = "Abilita Performance Insights"
  type        = bool
  default     = false
}

variable "performance_insights_retention" {
  description = "Retention period per Performance Insights (giorni)"
  type        = number
  default     = 7
}

variable "monitoring_interval" {
  description = "Enhanced Monitoring interval in secondi (0 per disabilitare)"
  type        = number
  default     = 0
}

variable "auto_minor_version_upgrade" {
  description = "Abilita upgrade automatici di versioni minori"
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "Applica modifiche immediatamente"
  type        = bool
  default     = false
}

variable "enable_cloudwatch_alarms" {
  description = "Abilita CloudWatch alarms"
  type        = bool
  default     = false
}

variable "cpu_alarm_threshold" {
  description = "Threshold percentuale CPU per alarm"
  type        = number
  default     = 80
}

variable "connection_alarm_threshold" {
  description = "Threshold connessioni per alarm"
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "ARN SNS per notifiche alarm"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio10RDS"
    CreatedBy   = "Terraform"
  }
}

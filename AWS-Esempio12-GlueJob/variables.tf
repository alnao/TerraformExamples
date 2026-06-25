variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Nome progetto usato come prefisso risorse"
  type        = string
  default     = "alnao-dev-terraform-esempio12-gluejob"
}

variable "bucket_name" {
  description = "Nome bucket S3"
  type        = string
  default     = "alnao-dev-terraform-esempio12-gluejob"
}

variable "force_destroy_bucket" {
  description = "Se true, svuota e distrugge il bucket al destroy"
  type        = bool
  default     = true
}

variable "step_function_name" {
  description = "Nome state machine"
  type        = string
  default     = "alnao-dev-terraform-esempio12-gluejob-sf"
}

variable "glue_job_name" {
  description = "Nome job Glue"
  type        = string
  default     = "alnao-dev-terraform-esempio12-glue-job"
}

variable "file_pattern" {
  description = "Pattern file excel da processare"
  type        = string
  default     = "*.xlsx"
}

variable "csv_file_pattern" {
  description = "Nome file CSV prodotto"
  type        = string
  default     = "lista.csv"
}

variable "source_path" {
  description = "Path S3 input excel"
  type        = string
  default     = "INPUT/excel"
}

variable "dest_csv_path" {
  description = "Path S3 output CSV"
  type        = string
  default     = "INPUT/lista"
}

variable "dest_path" {
  description = "Path S3 output elaborato Glue"
  type        = string
  default     = "OUTPUT/esiti"
}

variable "code_path" {
  description = "Path S3 dove caricare lo script Glue"
  type        = string
  default     = "CODE/glue"
}

variable "state_trigger_enabled" {
  description = "Abilita trigger EventBridge su upload S3"
  type        = bool
  default     = true
}

variable "lambda_runtime" {
  description = "Runtime Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Timeout Lambda in secondi"
  type        = number
  default     = 300
}

variable "lambda_memory_size" {
  description = "Memoria Lambda in MB"
  type        = number
  default     = 1024
}

variable "log_retention_days" {
  description = "Retention giorni log CloudWatch"
  type        = number
  default     = 7
}

variable "lambda_layer_arns_excel2csv" {
  description = "ARN dei layer Lambda necessari a excel2csv (openpyxl)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tag risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio12GlueJob"
    CreatedBy   = "Terraform"
  }
}

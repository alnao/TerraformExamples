variable "region" {
  description = "Regione AWS"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefisso usato per tutte le risorse create"
  type        = string
  default     = "alnao-dev-terraform-esempio16-rekognition"
}

# ====================================
# NOMI RISORSE (se vuoti derivano da project_name)
# ====================================

variable "bucket_name" {
  description = "Nome del bucket S3 delle immagini (vuoto = <project_name>-images)"
  type        = string
  default     = ""
}

variable "website_bucket_name" {
  description = "Nome del bucket S3 del sito statico (vuoto = <project_name>-web)"
  type        = string
  default     = ""
}

variable "table_name" {
  description = "Nome della tabella DynamoDB (vuoto = <project_name>-images)"
  type        = string
  default     = ""
}

variable "api_name" {
  description = "Nome della REST API (vuoto = <project_name>-api)"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "Nome dello stage di API Gateway"
  type        = string
  default     = "prod"
}

# ====================================
# REKOGNITION
# ====================================

variable "keyword_rilevante" {
  description = "Parola chiave che rende una immagine 'rilevante' (confronto case-insensitive su label e categorie padre)"
  type        = string
  default     = "airplane"
}

variable "min_confidence" {
  description = "Confidenza minima (0-100) delle label restituite da Rekognition"
  type        = number
  default     = 75
}

variable "max_labels" {
  description = "Numero massimo di label richieste a Rekognition per immagine"
  type        = number
  default     = 15
}

# ====================================
# S3 / UPLOAD
# ====================================

variable "input_prefix" {
  description = "Prefisso (cartella) del bucket dove vengono caricate le immagini da analizzare"
  type        = string
  default     = "input/"
}

variable "presigned_expiration" {
  description = "Durata in secondi del presigned URL di upload"
  type        = number
  default     = 3600
}

variable "force_destroy" {
  description = "Se true i bucket vengono cancellati anche se contengono oggetti"
  type        = bool
  default     = true
}

# ====================================
# CORS
# ====================================

variable "cors_allowed_origins" {
  description = "Origini ammesse per CORS su bucket S3 e API Gateway"
  type        = list(string)
  default     = ["*"]
}

# ====================================
# LOG E TAG
# ====================================

variable "log_retention_days" {
  description = "Giorni di retention dei log CloudWatch"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tag applicati a tutte le risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio16RekognitionImageDetector"
    CreatedBy   = "Terraform"
  }
}

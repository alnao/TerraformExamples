variable "region" {
  description = "Regione AWS (deve avere Amazon Textract disponibile)"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefisso usato per tutte le risorse create"
  type        = string
  default     = "alnao-dev-terraform-esempio17-textract"
}

# ====================================
# NOMI RISORSE (se vuoti derivano da project_name)
# ====================================

variable "bucket_name" {
  description = "Nome del bucket S3 dei documenti (vuoto = <project_name>-docs)"
  type        = string
  default     = ""
}

variable "website_bucket_name" {
  description = "Nome del bucket S3 del sito statico (vuoto = <project_name>-web)"
  type        = string
  default     = ""
}

variable "api_name" {
  description = "Nome della REST API (vuoto = <project_name>-api)"
  type        = string
  default     = ""
}

variable "sns_topic_name" {
  description = "Nome del topic SNS di notifica dei job Textract asincroni (vuoto = <project_name>-textract-done)"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "Nome dello stage di API Gateway"
  type        = string
  default     = "prod"
}

# ====================================
# S3 - PREFISSI
# Il bucket ha tre aree: le immagini caricate, i JSON di risultato e i
# file di opzioni scritti dalla lambda presigned_url.
# ====================================

variable "input_prefix" {
  description = "Prefisso del bucket dove vengono caricate le immagini da analizzare"
  type        = string
  default     = "input/"
}

variable "output_prefix" {
  description = "Prefisso del bucket dove vengono salvati i JSON con il testo estratto"
  type        = string
  default     = "output/"
}

variable "raw_prefix" {
  description = "Prefisso dove vengono salvati i blocchi grezzi di Textract (solo se richiesto nell'upload)"
  type        = string
  default     = "output-raw/"
}

variable "jobs_prefix" {
  description = "Prefisso dei file JSON con le opzioni Textract scelte al momento dell'upload"
  type        = string
  default     = "jobs/"
}

variable "jobs_expiration_days" {
  description = "Giorni dopo i quali i file di opzioni sotto jobs_prefix vengono cancellati automaticamente"
  type        = number
  default     = 7
}

# ====================================
# TEXTRACT - VALORI DI DEFAULT
# Sono i valori usati quando l'upload non porta con se' delle opzioni
# (per esempio quando il file viene copiato a mano con la AWS CLI).
# ====================================

variable "default_feature_types" {
  description = <<-EOT
    Feature Textract usate di default. Lista vuota = viene chiamata DetectDocumentText
    (solo testo), altrimenti viene chiamata AnalyzeDocument con queste feature.
    Valori ammessi: TABLES, FORMS, SIGNATURES, LAYOUT, QUERIES.
  EOT
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for feature in var.default_feature_types :
      contains(["TABLES", "FORMS", "SIGNATURES", "LAYOUT", "QUERIES"], feature)
    ])
    error_message = "Valori ammessi: TABLES, FORMS, SIGNATURES, LAYOUT, QUERIES."
  }
}

variable "default_queries" {
  description = <<-EOT
    Query di default per la feature QUERIES, nel formato [{ text = "...", alias = "..." }].
    Se valorizzata, la feature QUERIES viene aggiunta in automatico.
  EOT
  type = list(object({
    text  = string
    alias = string
  }))
  default = []
}

variable "min_confidence" {
  description = <<-EOT
    Confidenza minima (0-100) delle righe di testo tenute nel JSON di risultato.
    Attenzione: Textract non ha un parametro MinConfidence come Rekognition,
    il filtro viene applicato dalla Lambda sui blocchi restituiti.
  EOT
  type        = number
  default     = 80

  validation {
    condition     = var.min_confidence >= 0 && var.min_confidence <= 100
    error_message = "min_confidence deve essere compreso fra 0 e 100."
  }
}

variable "max_queries" {
  description = "Numero massimo di query accettate per singolo documento (limite Textract sincrono: 15)"
  type        = number
  default     = 15

  validation {
    condition     = var.max_queries >= 1 && var.max_queries <= 15
    error_message = "Le operazioni sincrone di Textract accettano al massimo 15 query."
  }
}

variable "salva_blocchi_grezzi" {
  description = "Se true salva anche la risposta completa di Textract sotto raw_prefix (default per gli upload che non specificano nulla)"
  type        = bool
  default     = false
}

# ====================================
# UPLOAD
# ====================================

variable "presigned_expiration" {
  description = "Durata in secondi del presigned URL di upload"
  type        = number
  default     = 3600
}

variable "preview_expiration" {
  description = "Durata in secondi dei presigned URL di anteprima e di download del JSON"
  type        = number
  default     = 900
}

variable "max_upload_mb" {
  description = "Dimensione massima delle IMMAGINI (Textract sincrono accetta al massimo 10 MB)"
  type        = number
  default     = 10

  validation {
    condition     = var.max_upload_mb > 0 && var.max_upload_mb <= 10
    error_message = "Le operazioni sincrone di Textract accettano immagini fino a 10 MB."
  }
}

variable "max_pdf_mb" {
  description = <<-EOT
    Dimensione massima dei PDF. Passano dalle operazioni asincrone Start*/Get*,
    che accettano file fino a 500 MB e 3.000 pagine: il default e' tenuto molto
    piu' basso perche' Textract si paga a pagina analizzata.
  EOT
  type        = number
  default     = 100

  validation {
    condition     = var.max_pdf_mb > 0 && var.max_pdf_mb <= 500
    error_message = "Le operazioni asincrone di Textract accettano PDF fino a 500 MB."
  }
}

variable "aggiungi_timestamp" {
  description = "Se true la key S3 viene prefissata con la data/ora, cosi' due upload con lo stesso nome non si sovrascrivono"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Se true i bucket vengono cancellati anche se contengono oggetti"
  type        = bool
  default     = true
}

# ====================================
# LAMBDA
# ====================================

variable "lambda_analyze_timeout" {
  description = "Timeout in secondi della Lambda che chiama Textract"
  type        = number
  default     = 120
}

variable "lambda_analyze_memory" {
  description = "Memoria in MB della Lambda che chiama Textract"
  type        = number
  default     = 512
}

variable "lambda_collect_timeout" {
  description = <<-EOT
    Timeout in secondi della Lambda che raccoglie i risultati dei job asincroni.
    Un PDF di molte pagine richiede parecchie chiamate Get* da 1.000 blocchi
    l'una, quindi il valore e' piu' alto di quello delle altre Lambda.
  EOT
  type        = number
  default     = 300
}

variable "lambda_collect_memory" {
  description = "Memoria in MB della Lambda che raccoglie i risultati dei job asincroni"
  type        = number
  default     = 1024
}

variable "lambda_max_retry" {
  description = <<-EOT
    Numero di retry dell'invocazione asincrona della Lambda di analisi (0, 1 o 2).
    Tenuto basso di proposito: ogni retry e' una nuova pagina fatturata da Textract.
  EOT
  type        = number
  default     = 1

  validation {
    condition     = contains([0, 1, 2], var.lambda_max_retry)
    error_message = "Le invocazioni asincrone Lambda ammettono 0, 1 o 2 retry."
  }
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
    Example     = "Esempio17Textract"
    CreatedBy   = "Terraform"
  }
}

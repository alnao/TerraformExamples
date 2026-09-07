variable "region" {
  description = "Regione AWS"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefisso usato per tutte le risorse create"
  type        = string
  default     = "alnao-dev-terraform-esempio19"
}

# ====================================
# I TAG OBBLIGATORI
# ====================================

variable "required_tag_keys" {
  description = "Tag che ogni risorsa deve avere. La regola nativa REQUIRED_TAGS ne accetta al massimo sei"
  type        = list(string)
  default     = ["project", "cost", "environment", "createdWith", "createdBy"]

  validation {
    condition     = length(var.required_tag_keys) > 0 && length(var.required_tag_keys) <= 6
    error_message = "La regola REQUIRED_TAGS di AWS Config accetta da uno a sei tag."
  }
}

variable "allowed_tag_values" {
  description = "Valori ammessi per alcuni tag; i tag non elencati accettano qualsiasi valore"
  type        = map(list(string))
  default = {
    environment = ["dev", "test", "prod"]
    createdWith = ["terraform", "console", "cli"]
  }
}

# ====================================
# AWS CONFIG
# ====================================

variable "create_config_recorder" {
  description = "Crea il configuration recorder. AWS ne ammette UNO SOLO per regione: mettere false se nell'account e' gia' attivo"
  type        = bool
  default     = true
}

variable "record_all_resources" {
  description = "Se true il recorder registra tutti i tipi di risorsa supportati, se false solo quelli in recorded_resource_types"
  type        = bool
  default     = false
}

variable "recorded_resource_types" {
  description = "Tipi di risorsa registrati quando record_all_resources = false; ridurre l'elenco riduce il costo di Config"
  type        = list(string)
  default = [
    "AWS::S3::Bucket",
    "AWS::EC2::Instance",
    "AWS::EC2::Volume",
    "AWS::EC2::SecurityGroup",
    "AWS::DynamoDB::Table",
    "AWS::RDS::DBInstance",
    "AWS::Lambda::Function",
  ]
}

variable "compliance_resource_types" {
  description = "Tipi di risorsa valutati dalla regola; lista vuota = tutti quelli registrati e supportati dalla regola"
  type        = list(string)
  default = [
    "AWS::S3::Bucket",
    "AWS::EC2::Instance",
    "AWS::EC2::Volume",
    "AWS::DynamoDB::Table",
    "AWS::RDS::DBInstance",
  ]
}

variable "delivery_frequency" {
  description = "Frequenza degli snapshot di configurazione consegnati su S3"
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition = contains([
      "One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"
    ], var.delivery_frequency)
    error_message = "Frequenza non valida per il delivery channel di AWS Config."
  }
}

variable "bucket_name" {
  description = "Bucket dove Config consegna snapshot e cronologia (vuoto = <project_name>-config-<account_id>)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "Giorni dopo i quali gli oggetti scritti da Config nel bucket vengono cancellati"
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Permette il destroy del bucket anche se contiene oggetti"
  type        = bool
  default     = true
}

# ====================================
# NOTIFICHE
# ====================================

variable "sns_topic_name" {
  description = "Nome del topic SNS (vuoto = <project_name>-non-compliant)"
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "Email iscritta al topic SNS (vuoto = nessuna iscrizione)"
  type        = string
  default     = ""
}

variable "enable_eventbridge_notification" {
  description = "Notifica su SNS ogni volta che una risorsa diventa NON_COMPLIANT"
  type        = bool
  default     = true
}

# ====================================
# RISORSE DI PROVA
# ====================================

variable "create_demo_resources" {
  description = "Crea due bucket S3, uno con tutti i tag e uno senza, per vedere subito la regola al lavoro"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tag applicati alle risorse dell'esempio"
  type        = map(string)
  default = {
    project     = "esempio19"
    cost        = "formazione"
    environment = "dev"
    createdWith = "terraform"
    createdBy   = "alnao"
  }
}

# ====================================
# CRUSCOTTO WEB: LAMBDA, API, SITO S3
# ====================================

variable "website_bucket_name" {
  description = "Bucket del sito statico (vuoto = <project_name>-web-<account_id>)"
  type        = string
  default     = ""
}

variable "api_name" {
  description = "Nome della REST API (vuoto = <project_name>-api)"
  type        = string
  default     = ""
}

variable "stage_name" {
  description = "Nome dello stage dell'API Gateway"
  type        = string
  default     = "dev"
}

variable "cors_allowed_origin" {
  description = "Origine autorizzata a chiamare l'API dal browser"
  type        = string
  default     = "*"
}

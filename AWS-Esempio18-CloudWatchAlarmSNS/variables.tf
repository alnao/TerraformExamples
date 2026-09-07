variable "region" {
  description = "Regione AWS"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefisso usato per tutte le risorse create"
  type        = string
  default     = "alnao-dev-terraform-esempio18"
}

# ====================================
# RETE E ISTANZA
# ====================================

variable "vpc_id" {
  description = "VPC dove creare l'istanza (vuoto = VPC di default dell'account)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet pubblica dove creare l'istanza (vuoto = prima subnet della VPC)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Tipo di istanza EC2"
  type        = string
  default     = "t3.micro"
}

variable "http_cidr_blocks" {
  description = "CIDR autorizzati a chiamare il sito in HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_ssh" {
  description = "Se true apre la porta 22; l'accesso alla console e' comunque possibile via SSM"
  type        = bool
  default     = false
}

variable "ssh_cidr_blocks" {
  description = "CIDR autorizzati in SSH (usati solo se enable_ssh = true)"
  type        = list(string)
  default     = []
}

variable "existing_key_name" {
  description = "Nome di una key pair gia' esistente (vuoto = nessuna, accesso solo via SSM)"
  type        = string
  default     = ""
}

# ====================================
# LOG, METRICA E ALLARME
# ====================================

variable "log_retention_days" {
  description = "Retention del log group degli accessi Apache"
  type        = number
  default     = 7
}

variable "monitored_status_code" {
  description = "Codice HTTP da intercettare nei log e da contare come errore (403 nell'esempio, 401 se il sito usa quello)"
  type        = number
  default     = 403
}

variable "alarm_threshold" {
  description = "Numero di errori nel periodo oltre il quale l'allarme scatta"
  type        = number
  default     = 1
}

variable "alarm_period_seconds" {
  description = "Ampiezza del periodo di valutazione dell'allarme, in secondi"
  type        = number
  default     = 60
}

variable "alarm_evaluation_periods" {
  description = "Numero di periodi consecutivi da valutare"
  type        = number
  default     = 1
}

# ====================================
# SNS
# ====================================

variable "sns_topic_name" {
  description = "Nome del topic SNS (vuoto = <project_name>-http-errors)"
  type        = string
  default     = ""
}

variable "notification_email" {
  description = "Email iscritta al topic SNS (vuoto = nessuna iscrizione, da aggiungere a mano)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tag applicati a tutte le risorse"
  type        = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

# ====================================
# ALLARMI AGGIUNTIVI
# ====================================

variable "enable_error_rate_alarm" {
  description = "Crea anche l'allarme sulla percentuale di errore invece che sul conteggio"
  type        = bool
  default     = true
}

variable "error_rate_threshold" {
  description = "Percentuale di richieste in errore oltre la quale scatta l'allarme sul rapporto"
  type        = number
  default     = 20
}

variable "enable_anomaly_alarm" {
  description = "Crea anche l'allarme ad anomaly detection (ha bisogno di ore di dati per essere utile)"
  type        = bool
  default     = true
}

variable "anomaly_band_width" {
  description = "Ampiezza della banda di normalita': piu' e' alta, meno l'allarme e' sensibile"
  type        = number
  default     = 2
}

# ====================================
# AUTENTICAZIONE DELL'AREA PRIVATA (/privata)
# Serve a mostrare la differenza vera fra 401 e 403.
# ====================================

variable "basic_auth_user" {
  description = "Utente abilitato all'area /privata"
  type        = string
  default     = "alnao"
}

variable "basic_auth_password" {
  description = "Password dell'utente abilitato (demo: non e' un segreto da produzione)"
  type        = string
  default     = "esempio18"
  sensitive   = true
}

variable "basic_auth_user_bloccato" {
  description = "Utente con credenziali valide ma non autorizzato: riceve 403 invece di 401"
  type        = string
  default     = "ospite"
}

variable "basic_auth_password_bloccato" {
  description = "Password dell'utente non autorizzato"
  type        = string
  default     = "ospite18"
  sensitive   = true
}

# ====================================
# STORICO ALLARMI: DYNAMODB, LAMBDA, API
# ====================================

variable "table_name" {
  description = "Nome della tabella DynamoDB (vuoto = <project_name>-allarmi)"
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

variable "ttl_days" {
  description = "Giorni di conservazione delle righe su DynamoDB prima della cancellazione automatica"
  type        = number
  default     = 30
}

variable "cors_allowed_origin" {
  description = "Origine autorizzata a chiamare l'API dal browser"
  type        = string
  default     = "*"
}

variable "root_volume_size" {
  description = "Dimensione del disco root in GB: non puo' essere inferiore allo snapshot dell'AMI (Amazon Linux 2023 parte da 30 GB)"
  type        = number
  default     = 30
}

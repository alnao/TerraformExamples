variable "region" {
  description = "Regione AWS"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefisso usato per tutte le risorse create"
  type        = string
  default     = "alnao-dev-terraform-esempio20"
}

# ====================================
# ECR E IMMAGINE
# ====================================

variable "repository_name" {
  description = "Nome del repository ECR (vuoto = <project_name>-pathsgames). L'esempio 21 lo usa per trovare l'immagine"
  type        = string
  default     = ""
}

variable "source_image" {
  description = "Immagine pubblica di Docker Hub da copiare su ECR (senza tag)"
  type        = string
  default     = "pathsgames/pathsgames"
}

variable "image_tag" {
  description = "Tag dell'immagine da copiare ed eseguire: cambiandolo viene copiata la nuova versione e l'istanza ricreata (meglio una versione precisa che latest)"
  type        = string
  default     = "1.12.0"

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.image_tag))
    error_message = "image_tag deve essere un tag Docker valido (lettere, numeri, '_', '.', '-', massimo 128 caratteri), es. 1.12.0."
  }
}

variable "image_platform" {
  description = "Piattaforma dell'immagine da copiare: linux/amd64 per istanze x86, linux/arm64 per Graviton"
  type        = string
  default     = "linux/amd64"
}

variable "image_tag_mutability" {
  description = "MUTABLE permette di sovrascrivere un tag, IMMUTABLE lo impedisce"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Scansione delle vulnerabilita' (basic scanning) a ogni push"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Numero massimo di immagini mantenute dalla lifecycle policy"
  type        = number
  default     = 5
}

# ====================================
# APPLICAZIONE E DATABASE
# ====================================

variable "postgres_image" {
  description = "Immagine di PostgreSQL (da ECR Public: niente limiti di pull di Docker Hub)"
  type        = string
  default     = "public.ecr.aws/docker/library/postgres:16-alpine"
}

variable "db_name" {
  description = "Nome del database PostgreSQL"
  type        = string
  default     = "pathsgames"
}

variable "db_username" {
  description = "Utente del database PostgreSQL"
  type        = string
  default     = "pathsgames"
}

variable "app_environment" {
  description = "Valore di ENVIRONMENT mostrato da /api/echo/status (diverso da dev/test: i segreti di default sono rifiutati)"
  type        = string
  default     = "aws-esempio20"
}

variable "host_port" {
  description = "Porta dell'istanza su cui viene pubblicata la porta 8042 del container"
  type        = number
  default     = 80
}

variable "log_retention_days" {
  description = "Retention del log group dei container"
  type        = number
  default     = 7
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
  description = "Tipo di istanza EC2: la JVM e postgres insieme stanno stretti in 1 GB, t3.small ne ha 2"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Dimensione in GB del disco root"
  type        = number
  default     = 20
}

variable "http_cidr_blocks" {
  description = "CIDR autorizzati a chiamare l'applicazione"
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Name        = "aws-esempio20.ecr"
    Environment = "dev"
    Project     = "Development.aws.terraform20-ECR"
    Owner       = "AlNao"
    CostCenter  = "dev"
    ManagedBy   = "Terraform"
  }
}

variable "region" {
  description = "Regione AWS (la stessa del repository ECR dell'esempio 20)"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefisso usato per tutte le risorse create"
  type        = string
  default     = "alnao-dev-terraform-esempio21"
}

# ====================================
# IMMAGINE
# ====================================

variable "ecr_repository_name" {
  description = "Repository ECR creato dall'esempio 20 con l'immagine di Paths Games"
  type        = string
  default     = "alnao-dev-terraform-esempio20-pathsgames"
}

variable "image_tag" {
  description = "Tag dell'immagine nel repository ECR (vuoto = immagine piu' recente, cioe' l'ultima copiata dall'esempio 20)"
  type        = string
  default     = ""

  validation {
    condition     = var.image_tag == "" || can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$", var.image_tag))
    error_message = "image_tag deve essere vuoto o un tag Docker valido (lettere, numeri, '_', '.', '-', massimo 128 caratteri), es. 1.12.0."
  }
}

variable "container_image" {
  description = "Immagine completa da usare al posto di quella su ECR (es. pathsgames/pathsgames:<versione>). Vuoto = ECR dell'esempio 20"
  type        = string
  default     = ""
}

variable "cpu_architecture" {
  description = "Architettura dei task Fargate: X86_64 o ARM64 (deve corrispondere all'immagine copiata su ECR)"
  type        = string
  default     = "X86_64"
}

# ====================================
# TASK E SERVICE
# ====================================

variable "task_cpu" {
  description = "CPU del task in unita' ECS (1024 = 1 vCPU), condivisa fra i due container"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memoria del task in MB, condivisa fra i due container"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Numero di task: 0 per spegnere il servizio senza distruggerlo, al massimo 1 perche' il database e' dentro il task"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 0 && var.desired_count <= 1
    error_message = "Con postgres come sidecar ogni task ha un database suo: desired_count deve essere 0 o 1."
  }
}

variable "enable_container_insights" {
  description = "Abilita Container Insights sul cluster (metriche dettagliate, a pagamento)"
  type        = bool
  default     = false
}

variable "enable_execute_command" {
  description = "Abilita ECS Exec per aprire una shell nei container (aws ecs execute-command)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Retention del log group dei container"
  type        = number
  default     = 7
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
  default     = "aws-esempio21"
}

# ====================================
# RETE
# ====================================

variable "vpc_id" {
  description = "VPC dove creare ALB e task (vuoto = VPC di default dell'account)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet pubbliche (almeno due in AZ diverse) per ALB e task (vuoto = tutte quelle della VPC)"
  type        = list(string)
  default     = []
}

variable "http_cidr_blocks" {
  description = "CIDR autorizzati a chiamare l'ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Name        = "aws-esempio21.ecs"
    Environment = "dev"
    Project     = "Development.aws.terraform21-ECS"
    Owner       = "AlNao"
    CostCenter  = "dev"
    ManagedBy   = "Terraform"
  }
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Nome progetto usato per naming risorse"
  type        = string
  default     = "alnao-dev-terraform-esempio15-wordpress-scaling"
}

variable "instance_type" {
  description = "Tipo istanza EC2 per bastion e nodi WordPress"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nome key pair EC2 per accesso SSH (opzionale)"
  type        = string
  default     = ""
}

variable "allowed_http_cidr" {
  description = "CIDR autorizzato per HTTP verso ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_https" {
  description = "Abilita listener HTTPS su ALB e redirect HTTP->HTTPS"
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ARN certificato ACM in stessa regione dell'ALB (richiesto se enable_https=true)"
  type        = string
  default     = ""
}

variable "allowed_ssh_cidr" {
  description = "CIDR autorizzato per SSH verso bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_name" {
  description = "Nome database WordPress"
  type        = string
  default     = "wordpressdb"
}

variable "db_username" {
  description = "Username database"
  type        = string
  default     = "wpadmin"
}

variable "db_password" {
  description = "Password database"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "db_instance_class" {
  description = "Classe istanza RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage iniziale RDS in GB"
  type        = number
  default     = 20
}

variable "rds_multi_az" {
  description = "Abilita deployment RDS Multi-AZ"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Giorni di retention backup RDS"
  type        = number
  default     = 0
}

variable "rds_deletion_protection" {
  description = "Abilita protezione cancellazione su RDS"
  type        = bool
  default     = false
}

variable "asg_min_size" {
  description = "Numero minimo di istanze nel gruppo autoscaling"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Numero desiderato di istanze nel gruppo autoscaling"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Numero massimo di istanze nel gruppo autoscaling"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target CPU medio ASG per policy di scaling"
  type        = number
  default     = 55
}

variable "alb_request_target_value" {
  description = "Target richieste per target ALB usato per scaling"
  type        = number
  default     = 500
}

variable "temporary_desired_capacity" {
  description = "Capacita temporanea impostata dalla lambda di incremento"
  type        = number
  default     = 3
}

variable "temporary_duration_hours" {
  description = "Durata in ore della capacita temporanea impostata dalla lambda"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio15WordpressScaling"
    CreatedBy   = "Terraform"
  }
}

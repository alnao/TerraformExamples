variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Nome progetto usato per naming risorse"
  type        = string
  default     = "alnao-dev-terraform-esempio14-wordpress-efs"
}

variable "instance_type" {
  description = "Tipo istanza EC2"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Nome key pair EC2 per accesso SSH (opzionale)"
  type        = string
  default     = ""
}

variable "allowed_ingress_cidr" {
  description = "CIDR autorizzato per HTTP/SSH verso EC2"
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
  description = "Classe istanza RDS (piccola/economica)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Storage iniziale RDS in GB"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Tags da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio14WordpressEFS"
    CreatedBy   = "Terraform"
  }
}

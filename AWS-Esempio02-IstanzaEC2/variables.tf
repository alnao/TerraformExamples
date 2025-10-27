variable "region" {
  description = "AWS region where to create resources"
  type        = string
  default     = "eu-central-1" # Francoforte
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "aws-esempio02-ec2"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID to use for the instance (leave empty to use latest Amazon Linux 2023)"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC ID where to create the instance"
  type        = string
  default     = "" # Usare il VPC default se non specificato
}

variable "subnet_id" {
  description = "Subnet ID where to create the instance"
  type        = string
  default     = "" # Usare la subnet default se non specificato
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # ATTENZIONE: limitare in produzione!
}

variable "http_cidr_blocks" {
  description = "CIDR blocks allowed for HTTP access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_cidr_blocks" {
  description = "CIDR blocks allowed for HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_key_pair" {
  description = "Create a new key pair for SSH access"
  type        = bool
  default     = false
}

variable "public_key" {
  description = "Public key for SSH access (required if create_key_pair is true)"
  type        = string
  default     = ""
}

variable "existing_key_name" {
  description = "Existing key pair name to use (required if create_key_pair is false)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of root volume (gp2, gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "delete_volume_on_termination" {
  description = "Delete volume on instance termination"
  type        = bool
  default     = true
}

variable "encrypt_volume" {
  description = "Encrypt root volume"
  type        = bool
  default     = true
}

variable "user_data" {
  description = "User data script to run on instance launch"
  type        = string
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "associate_public_ip" {
  description = "Associate a public IP address"
  type        = bool
  default     = true
}

variable "create_eip" {
  description = "Create and associate an Elastic IP"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio02IstanzaEC2"
    CreatedBy   = "Terraform"
  }
}

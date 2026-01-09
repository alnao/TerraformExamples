variable "region" {
  description = "AWS region where to create resources"
  type        = string
  default     = "eu-central-1" # Francoforte
}

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "aws-esempio02-ec2-module"
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

variable "key_name" {
  description = "Key pair name to use for SSH access"
  type        = string
  default     = ""
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
  default     = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from EC2 Instance created with Terraform Module!</h1>" > /var/www/html/index.html
    echo "<p>Instance ID: $(ec2-metadata --instance-id | cut -d ' ' -f 2)</p>" >> /var/www/html/index.html
    echo "<p>Availability Zone: $(ec2-metadata --availability-zone | cut -d ' ' -f 2)</p>" >> /var/www/html/index.html
  EOF
}

variable "create_eip" {
  description = "Create an Elastic IP and associate it with the instance"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for the instance"
  type        = bool
  default     = false
}

variable "enable_termination_protection" {
  description = "Enable termination protection for the instance"
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile to associate with the instance"
  type        = string
  default     = ""
}

variable "additional_ebs_volumes" {
  description = "Additional EBS volumes to attach to the instance"
  type = list(object({
    device_name           = string
    volume_type           = string
    volume_size           = number
    delete_on_termination = bool
    encrypted             = bool
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "Development"
    Project     = "TerraformExamples"
    Example     = "AWS-Esempio02-IstanzaEC2-module"
  }
}

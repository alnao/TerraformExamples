terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Ricerca dell'AMI più recente di Amazon Linux 2023
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group per l'istanza EC2
resource "aws_security_group" "ec2_sg" {
  name        = "${var.instance_name}-sg"
  description = "Security group for EC2 instance ${var.instance_name}"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : null

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidr_blocks
    description = "SSH access"
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_cidr_blocks
    description = "HTTP access"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.https_cidr_blocks
    description = "HTTPS access"
  }

  # Outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.instance_name}-sg"
    }
  )
}

# Modulo EC2 dal Terraform Registry
# https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.6"

  name = var.instance_name

  # AMI
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  monitoring             = var.enable_detailed_monitoring
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = var.subnet_id != "" ? var.subnet_id : null
  
  # User data
  user_data_base64            = var.user_data != "" ? base64encode(var.user_data) : null
  user_data_replace_on_change = true

  # Root volume configuration
  root_block_device = [
    {
      volume_type           = var.root_volume_type
      volume_size           = var.root_volume_size
      delete_on_termination = var.delete_volume_on_termination
      encrypted             = var.encrypt_volume
    }
  ]

  # EBS volumes aggiuntivi (opzionale)
  ebs_block_device = var.additional_ebs_volumes

  # Metadata options
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Enable termination protection (opzionale)
  disable_api_termination = var.enable_termination_protection

  # IAM Instance Profile (opzionale)
  iam_instance_profile = var.iam_instance_profile

  # Tags
  tags = var.tags
}

# Elastic IP (opzionale)
resource "aws_eip" "ec2_eip" {
  count    = var.create_eip ? 1 : 0
  domain   = "vpc"
  instance = module.ec2_instance.id

  tags = merge(
    var.tags,
    {
      Name = "${var.instance_name}-eip"
    }
  )
}

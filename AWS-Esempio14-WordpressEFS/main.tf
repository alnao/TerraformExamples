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

locals {
  first_subnet_id = data.aws_subnets.default.ids[0]
  common_tags = merge(
    var.tags,
    {
      Project = var.project_name
    }
  )
}

# VPC e Subnet di default per un setup semplice

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Amazon Linux 2 (x86_64) compatibile con t2.micro

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Security group EC2 WordPress"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidr
    description = "SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidr
    description = "HTTP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ec2-sg"
    }
  )
}

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "Security group EFS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
    description     = "NFS from EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-efs-sg"
    }
  )
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group RDS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
    description     = "MySQL from EC2"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-rds-sg"
    }
  )
}

resource "aws_efs_file_system" "wordpress" {
  creation_token = "${var.project_name}-efs"
  encrypted      = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-efs"
    }
  )
}

resource "aws_efs_mount_target" "wordpress" {
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = local.first_subnet_id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_db_subnet_group" "wordpress" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-db-subnet-group"
    }
  )
}

resource "aws_db_instance" "wordpress" {
  identifier              = "${var.project_name}-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = 100
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  port                    = 3306
  publicly_accessible     = false
  storage_encrypted       = true
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0

  db_subnet_group_name   = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-db"
    }
  )
}

resource "aws_instance" "wordpress" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  key_name                    = var.key_name != "" ? var.key_name : null
  subnet_id                   = local.first_subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -xe

              yum update -y
              amazon-linux-extras enable php8.1
              yum clean metadata
              yum install -y httpd php php-mysqlnd wget tar amazon-efs-utils nfs-utils

              systemctl enable httpd
              systemctl start httpd

              mkdir -p /var/www/html
              mount -t efs -o tls ${aws_efs_file_system.wordpress.id}:/ /var/www/html
              echo "${aws_efs_file_system.wordpress.id}:/ /var/www/html efs defaults,_netdev,tls 0 0" >> /etc/fstab

              cd /tmp
              wget https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz

              if [ ! -f /var/www/html/wp-config.php ]; then
                cp -r /tmp/wordpress/* /var/www/html/
                cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
                sed -i "s/database_name_here/${var.db_name}/" /var/www/html/wp-config.php
                sed -i "s/username_here/${var.db_username}/" /var/www/html/wp-config.php
                sed -i "s/password_here/${var.db_password}/" /var/www/html/wp-config.php
                sed -i "s/localhost/${aws_db_instance.wordpress.address}/" /var/www/html/wp-config.php
                chown -R apache:apache /var/www/html
                chmod -R 755 /var/www/html
              fi

              systemctl restart httpd
              EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-ec2"
    }
  )

  depends_on = [
    aws_efs_mount_target.wordpress,
    aws_db_instance.wordpress
  ]
}

resource "aws_eip" "wordpress" {
  instance = aws_instance.wordpress.id
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-eip"
    }
  )
}

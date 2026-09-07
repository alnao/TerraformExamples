# ====================================
# RUOLO IAM DELL'ISTANZA
# Serve al CloudWatch Agent per creare stream e scrivere eventi;
# SSM permette di collegarsi alla macchina senza aprire la porta 22.
# ====================================

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
  tags = local.common_tags
}

# ====================================
# SECURITY GROUP
# ====================================

resource "aws_security_group" "web" {
  name        = "${var.project_name}-sg"
  description = "Security group del web server esempio 18"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_cidr_blocks
    description = "HTTP access"
  }

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_cidr_blocks
      description = "SSH access"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-sg" })
}

# ====================================
# ISTANZA EC2 CON APACHE
# ====================================

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.selected.ids[0]
  vpc_security_group_ids      = [aws_security_group.web.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  key_name                    = var.existing_key_name != "" ? var.existing_key_name : null
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh", {
    log_group_name         = local.log_group_name
    ko_status_code         = var.monitored_status_code
    auth_user              = var.basic_auth_user
    auth_password          = var.basic_auth_password
    auth_user_bloccato     = var.basic_auth_user_bloccato
    auth_password_bloccato = var.basic_auth_password_bloccato
    pagina_allarmi = templatefile("${path.module}/website/allarmi.html.tpl", {
      api_url = local.api_url
    })
  })

  # Il log group deve esistere prima che l'agent provi a scriverci
  depends_on = [aws_cloudwatch_log_group.httpd]

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-web" })
}

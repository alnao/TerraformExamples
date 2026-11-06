# ====================================
# LOG GROUP DEI CONTAINER
# Docker usa il driver awslogs: lo stdout di pathsgames e postgres finisce qui.
# ====================================

resource "aws_cloudwatch_log_group" "containers" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "aws-esempio20.log-group" })
}

# ====================================
# RUOLO IAM DELL'ISTANZA
# - lettura dal repository ECR (pull dell'immagine)
# - lettura dei tre parametri SSM con i segreti
# - scrittura dei log dei container su CloudWatch
# - SSM Session Manager per collegarsi senza aprire la porta 22
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

  tags = merge(local.common_tags, { Name = "aws-esempio20.ec2-role" })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Policy dedicata (taggabile) al posto di una inline: segreti e log del solo esempio
resource "aws_iam_policy" "ec2_app" {
  name        = "${var.project_name}-ec2-app-policy"
  description = "Lettura dei segreti SSM e scrittura dei log dei container dell'esempio 20"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadSecrets"
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = [
          aws_ssm_parameter.db_password.arn,
          aws_ssm_parameter.jwt_secret.arn,
          aws_ssm_parameter.banned_subject_pepper.arn,
        ]
      },
      {
        Sid      = "WriteContainerLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
        Resource = "${aws_cloudwatch_log_group.containers.arn}:*"
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "aws-esempio20.ec2-app-policy" })
}

resource "aws_iam_role_policy_attachment" "ec2_app" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ec2_app.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name

  tags = merge(local.common_tags, { Name = "aws-esempio20.ec2-profile" })
}

# ====================================
# SECURITY GROUP
# Viene esposta solo la porta pubblica dell'applicazione; la porta admin
# (8044) non viene pubblicata da Docker e resta raggiungibile solo dall'istanza.
# ====================================

resource "aws_security_group" "web" {
  name        = "${var.project_name}-sg"
  description = "Security group del server Paths Games esempio 20"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = var.host_port
    to_port     = var.host_port
    protocol    = "tcp"
    cidr_blocks = var.http_cidr_blocks
    description = "HTTP access to Paths Games"
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

  tags = merge(local.common_tags, { Name = "aws-esempio20.sg" })
}

# ====================================
# ISTANZA EC2 CON DOCKER
# Lo user data installa Docker, fa login su ECR e avvia due container sulla
# stessa rete docker: postgres e pathsgames (immagine presa da ECR).
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
    region            = var.region
    registry          = split("/", aws_ecr_repository.pathsgames.repository_url)[0]
    image_uri         = local.image_uri
    postgres_image    = var.postgres_image
    db_name           = var.db_name
    db_username       = var.db_username
    host_port         = var.host_port
    environment_name  = var.app_environment
    log_group_name    = aws_cloudwatch_log_group.containers.name
    ssm_db_password   = aws_ssm_parameter.db_password.name
    ssm_jwt_secret    = aws_ssm_parameter.jwt_secret.name
    ssm_banned_pepper = aws_ssm_parameter.banned_subject_pepper.name
  })
  # Se cambia l'immagine (o un altro parametro dello script) l'istanza viene ricreata
  user_data_replace_on_change = true

  # L'immagine deve essere gia' su ECR prima che l'istanza provi a scaricarla
  depends_on = [
    terraform_data.push_image,
    aws_iam_role_policy_attachment.ecr_read,
    aws_iam_role_policy_attachment.ec2_app,
  ]

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
    tags                  = merge(local.common_tags, { Name = "aws-esempio20.root-volume" })
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(local.common_tags, { Name = "aws-esempio20.web" })
}

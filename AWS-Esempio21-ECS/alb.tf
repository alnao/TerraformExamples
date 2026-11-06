# ====================================
# SECURITY GROUP
# Internet -> ALB sulla porta 80, ALB -> task sulla 8042. I task non sono
# raggiungibili direttamente anche se hanno un IP pubblico.
# ====================================

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group ALB esempio 21"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_cidr_blocks
    description = "HTTP access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, { Name = "aws-esempio21.alb-sg" })
}

resource "aws_security_group" "task" {
  name        = "${var.project_name}-task-sg"
  description = "Security group dei task ECS esempio 21"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port       = local.app_port
    to_port         = local.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Paths Games from ALB only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic (ECR, SSM, CloudWatch)"
  }

  tags = merge(local.common_tags, { Name = "aws-esempio21.task-sg" })
}

# ====================================
# APPLICATION LOAD BALANCER
# ====================================

resource "aws_lb" "main" {
  name               = substr("${var.project_name}-alb", 0, 32)
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.subnet_ids

  tags = merge(local.common_tags, { Name = "aws-esempio21.alb" })
}

# target_type "ip": con awsvpc (obbligatorio su Fargate) ogni task ha la sua ENI
resource "aws_lb_target_group" "app" {
  name                 = substr("${var.project_name}-tg", 0, 32)
  port                 = local.app_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.selected.id
  deregistration_delay = 30

  health_check {
    path                = "/api/echo/status"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, { Name = "aws-esempio21.tg" })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = merge(local.common_tags, { Name = "aws-esempio21.listener-http" })
}

# ====================================
# TAG DI ENI ED ELASTIC IP DELL'ALB
# Un ALB pubblico crea da solo una ENI e un Elastic IP (ServiceManaged = alb)
# per ogni nodo: non sono risorse Terraform, l'ALB non propaga loro i tag e il
# loro numero lo decide AWS (puo' crescere quando l'ALB scala), quindi non si
# possono gestire con aws_ec2_tag e for_each. Lo script li cerca e li tagga
# dopo la creazione dell'ALB; viene rieseguito se cambiano ALB o tag comuni.
# terraform_data non e' una risorsa AWS, quindi non ha tag.
# ====================================

resource "terraform_data" "tag_alb_network" {
  triggers_replace = [
    aws_lb.main.arn,
    local.common_tags,
  ]

  provisioner "local-exec" {
    command = "${path.module}/tag_alb_network.sh"
    environment = {
      AWS_REGION    = var.region
      LB_ARN_SUFFIX = aws_lb.main.arn_suffix
      TAGS_ENI      = jsonencode([for k, v in merge(local.common_tags, { Name = "aws-esempio21.alb-eni" }) : { Key = k, Value = v }])
      TAGS_EIP      = jsonencode([for k, v in merge(local.common_tags, { Name = "aws-esempio21.alb-eip" }) : { Key = k, Value = v }])
    }
  }
}

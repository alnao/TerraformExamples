terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.5"
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

  scaling_expiration_parameter = "/${var.project_name}/scaling/temporary-expire-at"
}

# VPC e subnet di default per esempio rapido

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Amazon Linux 2 (x86_64)

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidr
    description = "HTTPS"
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
      Name = "${var.project_name}-alb-sg"
    }
  )
}

resource "aws_security_group" "wordpress" {
  name        = "${var.project_name}-wordpress-sg"
  description = "Security group istanze WordPress in autoscaling"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "HTTP from ALB"
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
      Name = "${var.project_name}-wordpress-sg"
    }
  )
}

resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Security group bastion"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
    description = "SSH"
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
      Name = "${var.project_name}-bastion-sg"
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
    security_groups = [aws_security_group.wordpress.id, aws_security_group.bastion.id]
    description     = "NFS from WordPress and bastion"
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
    security_groups = [aws_security_group.wordpress.id, aws_security_group.bastion.id]
    description     = "MySQL from WordPress and bastion"
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
  for_each = toset(data.aws_subnets.default.ids)

  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = each.value
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
  multi_az                = var.rds_multi_az
  skip_final_snapshot     = true
  deletion_protection     = var.rds_deletion_protection
  backup_retention_period = var.rds_backup_retention_period

  db_subnet_group_name   = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-db"
    }
  )
}

resource "aws_lb" "wordpress" {
  name               = substr(replace("${var.project_name}-alb", "_", "-"), 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-alb"
    }
  )
}

resource "aws_lb_target_group" "wordpress" {
  name        = substr(replace("${var.project_name}-tg", "_", "-"), 0, 32)
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-tg"
    }
  )
}

resource "aws_lb_listener" "http_forward" {
  count = var.enable_https ? 0 : 1

  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.wordpress.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

resource "aws_launch_template" "wordpress" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  vpc_security_group_ids = [aws_security_group.wordpress.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -xe

    yum update -y
    amazon-linux-extras enable php8.1
    yum clean metadata
    yum install -y httpd php php-mysqlnd wget tar amazon-efs-utils nfs-utils

    mkdir -p /var/www/html
    mount -t efs -o tls ${aws_efs_file_system.wordpress.id}:/ /var/www/html

    if ! grep -q '${aws_efs_file_system.wordpress.id}:/ /var/www/html' /etc/fstab; then
      echo '${aws_efs_file_system.wordpress.id}:/ /var/www/html efs defaults,_netdev,tls 0 0' >> /etc/fstab
    fi

    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz -O latest.tar.gz
    tar -xzf latest.tar.gz

    if [ ! -f /var/www/html/wp-config.php ]; then
      cp -r /tmp/wordpress/* /var/www/html/
      cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
      sed -i 's/database_name_here/${var.db_name}/' /var/www/html/wp-config.php
      sed -i 's/username_here/${var.db_username}/' /var/www/html/wp-config.php
      sed -i 's/password_here/${var.db_password}/' /var/www/html/wp-config.php
      sed -i 's/localhost/${aws_db_instance.wordpress.address}/' /var/www/html/wp-config.php
    fi

    chown -R apache:apache /var/www/html
    chmod -R 755 /var/www/html

    systemctl enable httpd
    systemctl restart httpd
    EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project_name}-asg-instance"
      }
    )
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-launch-template"
    }
  )

  depends_on = [
    aws_efs_mount_target.wordpress,
    aws_db_instance.wordpress
  ]
}

resource "aws_autoscaling_group" "wordpress" {
  name                = "${var.project_name}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = data.aws_subnets.default.ids
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.wordpress.arn]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = lookup(var.tags, "Environment", "Dev")
    propagate_at_launch = true
  }

  depends_on = [
    aws_lb_listener.http_forward,
    aws_lb_listener.http_redirect,
    aws_lb_listener.https
  ]
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.cpu_target_value
  }
}

resource "aws_autoscaling_policy" "alb_requests_target" {
  name                   = "${var.project_name}-alb-requests-target"
  autoscaling_group_name = aws_autoscaling_group.wordpress.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.wordpress.arn_suffix}/${aws_lb_target_group.wordpress.arn_suffix}"
    }

    target_value = var.alb_request_target_value
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  key_name                    = var.key_name != "" ? var.key_name : null
  subnet_id                   = local.first_subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -xe

    yum update -y
    amazon-linux-extras enable php8.1
    yum clean metadata
    yum install -y httpd php php-mysqlnd wget tar amazon-efs-utils nfs-utils

    mkdir -p /var/www/html
    mount -t efs -o tls ${aws_efs_file_system.wordpress.id}:/ /var/www/html

    if ! grep -q '${aws_efs_file_system.wordpress.id}:/ /var/www/html' /etc/fstab; then
      echo '${aws_efs_file_system.wordpress.id}:/ /var/www/html efs defaults,_netdev,tls 0 0' >> /etc/fstab
    fi

    cd /tmp
    wget -q https://wordpress.org/latest.tar.gz -O latest.tar.gz
    tar -xzf latest.tar.gz

    if [ ! -f /var/www/html/wp-config.php ]; then
      cp -r /tmp/wordpress/* /var/www/html/
      cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
      sed -i 's/database_name_here/${var.db_name}/' /var/www/html/wp-config.php
      sed -i 's/username_here/${var.db_username}/' /var/www/html/wp-config.php
      sed -i 's/password_here/${var.db_password}/' /var/www/html/wp-config.php
      sed -i 's/localhost/${aws_db_instance.wordpress.address}/' /var/www/html/wp-config.php
    fi

    chown -R apache:apache /var/www/html
    chmod -R 755 /var/www/html

    systemctl enable httpd
    systemctl restart httpd
    EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-bastion"
    }
  )

  depends_on = [
    aws_efs_mount_target.wordpress,
    aws_db_instance.wordpress
  ]
}

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-bastion-eip"
    }
  )
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_scaling" {
  name               = "${var.project_name}-lambda-scaling-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-lambda-scaling-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_scaling.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_scaling" {
  statement {
    sid = "AutoscalingControl"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:UpdateAutoScalingGroup"
    ]

    resources = ["*"]
  }

  statement {
    sid = "SsmParameterControl"

    actions = [
      "ssm:GetParameter",
      "ssm:PutParameter",
      "ssm:DeleteParameter"
    ]

    resources = [
      "arn:aws:ssm:${var.region}:*:parameter${local.scaling_expiration_parameter}"
    ]
  }
}

resource "aws_iam_policy" "lambda_scaling" {
  name   = "${var.project_name}-lambda-scaling-policy"
  policy = data.aws_iam_policy_document.lambda_scaling.json
}

resource "aws_iam_role_policy_attachment" "lambda_scaling" {
  role       = aws_iam_role.lambda_scaling.name
  policy_arn = aws_iam_policy.lambda_scaling.arn
}

data "archive_file" "scale_up" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/scale_up.py"
  output_path = "${path.module}/lambda_functions/scale_up.zip"
}

data "archive_file" "scale_down" {
  type        = "zip"
  source_file = "${path.module}/lambda_functions/scale_down.py"
  output_path = "${path.module}/lambda_functions/scale_down.zip"
}

resource "aws_lambda_function" "scale_up" {
  function_name = "${var.project_name}-scale-up"
  role          = aws_iam_role.lambda_scaling.arn
  handler       = "scale_up.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.scale_up.output_path
  source_code_hash = data.archive_file.scale_up.output_base64sha256

  environment {
    variables = {
      ASG_NAME          = aws_autoscaling_group.wordpress.name
      DEFAULT_DESIRED   = tostring(var.asg_desired_capacity)
      TEMP_DESIRED      = tostring(var.temporary_desired_capacity)
      DURATION_HOURS    = tostring(var.temporary_duration_hours)
      PARAMETER_NAME    = local.scaling_expiration_parameter
      MAX_CAPACITY      = tostring(var.asg_max_size)
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-scale-up"
    }
  )
}

resource "aws_lambda_function" "scale_down" {
  function_name = "${var.project_name}-scale-down"
  role          = aws_iam_role.lambda_scaling.arn
  handler       = "scale_down.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30

  filename         = data.archive_file.scale_down.output_path
  source_code_hash = data.archive_file.scale_down.output_base64sha256

  environment {
    variables = {
      ASG_NAME        = aws_autoscaling_group.wordpress.name
      DEFAULT_DESIRED = tostring(var.asg_desired_capacity)
      PARAMETER_NAME  = local.scaling_expiration_parameter
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-scale-down"
    }
  )
}

resource "aws_cloudwatch_event_rule" "scale_down_checker" {
  name                = "${var.project_name}-scale-down-checker"
  description         = "Esegue periodicamente la lambda che riduce la capacita temporanea"
  schedule_expression = "rate(15 minutes)"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-scale-down-checker"
    }
  )
}

resource "aws_cloudwatch_event_target" "scale_down_lambda" {
  rule      = aws_cloudwatch_event_rule.scale_down_checker.name
  target_id = "ScaleDownLambda"
  arn       = aws_lambda_function.scale_down.arn
}

resource "aws_lambda_permission" "allow_eventbridge_scale_down" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_down.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down_checker.arn
}

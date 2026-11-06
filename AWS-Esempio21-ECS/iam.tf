# ====================================
# EXECUTION ROLE
# Usato dall'agente ECS (non dall'applicazione) per: scaricare l'immagine da
# ECR, scrivere i log su CloudWatch e leggere i segreti da SSM.
# ====================================

resource "aws_iam_role" "execution" {
  name = "${var.project_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, { Name = "aws-esempio21.execution-role" })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "execution_secrets" {
  name        = "${var.project_name}-execution-secrets"
  description = "Lettura dei segreti SSM dell'esempio 21 da parte dell'agente ECS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadSecrets"
      Effect = "Allow"
      Action = ["ssm:GetParameters"]
      Resource = [
        aws_ssm_parameter.db_password.arn,
        aws_ssm_parameter.jwt_secret.arn,
        aws_ssm_parameter.banned_subject_pepper.arn,
      ]
    }]
  })

  tags = merge(local.common_tags, { Name = "aws-esempio21.execution-secrets-policy" })
}

resource "aws_iam_role_policy_attachment" "execution_secrets" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution_secrets.arn
}

# ====================================
# TASK ROLE
# I permessi dell'applicazione dentro il container. Paths Games non chiama
# servizi AWS: serve solo a ECS Exec (shell nel container), se abilitato.
# ====================================

resource "aws_iam_role" "task" {
  name = "${var.project_name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, { Name = "aws-esempio21.task-role" })
}

resource "aws_iam_policy" "task_exec" {
  count       = var.enable_execute_command ? 1 : 0
  name        = "${var.project_name}-task-ecs-exec"
  description = "Canali SSM usati da ECS Exec per aprire una shell nel container"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    }]
  })

  tags = merge(local.common_tags, { Name = "aws-esempio21.task-ecs-exec-policy" })
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  count      = var.enable_execute_command ? 1 : 0
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_exec[0].arn
}

# ====================================
# LOG GROUP DEI CONTAINER
# ====================================

resource "aws_cloudwatch_log_group" "containers" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "aws-esempio21.log-group" })
}

# ====================================
# CLUSTER ECS
# ====================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge(local.common_tags, { Name = "aws-esempio21.cluster" })
}

# ====================================
# TASK DEFINITION
# Due container nello stesso task: con la rete awsvpc condividono
# l'interfaccia di rete, quindi pathsgames raggiunge postgres su localhost.
# Il database e' un "sidecar": i dati vivono quanto il task. Per dati
# persistenti e piu' task servirebbe RDS (vedi esempio 10).
# ====================================

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-pathsgames"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = "postgres"
      image     = var.postgres_image
      essential = true

      environment = [
        { name = "POSTGRES_DB", value = var.db_name },
        { name = "POSTGRES_USER", value = var.db_username },
      ]
      secrets = [
        { name = "POSTGRES_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U ${var.db_username} -d ${var.db_name}"]
        interval    = 10
        timeout     = 5
        retries     = 5
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.containers.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "postgres"
        }
      }
    },
    {
      name      = "pathsgames"
      image     = local.image_uri
      essential = true

      # Parte solo quando il database risponde
      dependsOn = [
        { containerName = "postgres", condition = "HEALTHY" },
      ]

      # Solo la porta pubblica: la 8044 (admin) non viene esposta
      portMappings = [
        { containerPort = local.app_port, protocol = "tcp" },
      ]

      environment = [
        { name = "SPRING_PROFILES_ACTIVE", value = "prod" },
        { name = "ENVIRONMENT", value = var.app_environment },
        { name = "DB_HOST", value = "localhost" },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USERNAME", value = var.db_username },
        # L'ALB aggiunge X-Forwarded-For: l'app lo considera solo se arriva da un proxy fidato
        { name = "TRUSTED_PROXIES", value = data.aws_vpc.selected.cidr_block },
      ]
      secrets = [
        { name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn },
        { name = "JWT_SECRET", valueFrom = aws_ssm_parameter.jwt_secret.arn },
        { name = "BANNED_SUBJECT_PEPPER", valueFrom = aws_ssm_parameter.banned_subject_pepper.arn },
      ]

      # L'immagine (alpine) ha wget ma non curl
      healthCheck = {
        command     = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:${local.app_port}/api/echo/status || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 90
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.containers.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "pathsgames"
        }
      }
    },
  ])

  tags = merge(local.common_tags, { Name = "aws-esempio21.task-definition" })
}

# ====================================
# SERVICE
# Mantiene in vita desired_count task e li registra nel target group.
# propagate_tags copia i tag del servizio sui task, cosi' anche le risorse
# create a runtime da ECS (task ed ENI gestite) risultano taggate.
# ====================================

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"
  enable_execute_command  = var.enable_execute_command

  # La JVM impiega una decina di secondi a partire, flyway compreso
  health_check_grace_period_seconds = 120

  # Ogni task ha il suo database: durante un deploy il vecchio task viene
  # fermato prima di avviare il nuovo, mai due versioni insieme dietro l'ALB
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  # Se il nuovo task non diventa healthy, ECS torna alla revisione precedente
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "pathsgames"
    container_port   = local.app_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.execution_managed,
    aws_iam_role_policy_attachment.execution_secrets,
  ]

  tags = merge(local.common_tags, { Name = "aws-esempio21.service" })
}

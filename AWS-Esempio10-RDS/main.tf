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

# VPC e Networking
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group per RDS
resource "aws_security_group" "rds" {
  name        = "${var.cluster_identifier}-sg"
  description = "Security group per RDS Aurora cluster"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
    description = "MySQL/Aurora access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_identifier}-sg"
    }
  )
}

# Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_identifier}-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_identifier}-subnet-group"
    }
  )
}

# Parameter Group per Aurora MySQL
resource "aws_rds_cluster_parameter_group" "main" {
  name        = "${var.cluster_identifier}-cluster-params"
  family      = "aurora-mysql8.0"
  description = "Custom parameter group for ${var.cluster_identifier}"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = var.tags
}

resource "aws_db_parameter_group" "main" {
  name        = "${var.cluster_identifier}-instance-params"
  family      = "aurora-mysql8.0"
  description = "Custom instance parameter group for ${var.cluster_identifier}"

  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name  = "log_queries_not_using_indexes"
    value = "1"
  }

  tags = var.tags
}

# IAM Role per Enhanced Monitoring (se abilitato)
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0
  name  = "${var.cluster_identifier}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.monitoring_interval > 0 ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Aurora Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier              = var.cluster_identifier
  engine                          = var.engine
  engine_version                  = var.engine_version
  database_name                   = var.database_name
  master_username                 = var.master_username
  master_password                 = var.master_password
  
  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  
  backup_retention_period         = var.backup_retention_period
  preferred_backup_window         = var.preferred_backup_window
  preferred_maintenance_window    = var.preferred_maintenance_window
  
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.cluster_identifier}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  deletion_protection             = var.deletion_protection
  
  storage_encrypted               = var.storage_encrypted
  kms_key_id                      = var.kms_key_id != "" ? var.kms_key_id : null
  
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  enable_http_endpoint            = var.enable_http_endpoint
  
  apply_immediately               = var.apply_immediately
  
  tags = var.tags

  lifecycle {
    ignore_changes = [
      master_password,
      final_snapshot_identifier
    ]
  }
}

# Aurora Cluster Instances
resource "aws_rds_cluster_instance" "main" {
  count              = var.instance_count
  identifier         = "${var.cluster_identifier}-instance-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
  
  db_parameter_group_name    = aws_db_parameter_group.main.name
  publicly_accessible        = var.publicly_accessible
  
  performance_insights_enabled    = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? var.performance_insights_retention : null
  
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  
  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_identifier}-instance-${count.index + 1}"
    }
  )
}

# CloudWatch Log Groups (per la retention)
resource "aws_cloudwatch_log_group" "audit" {
  count             = contains(var.enabled_cloudwatch_logs_exports, "audit") ? 1 : 0
  name              = "/aws/rds/cluster/${var.cluster_identifier}/audit"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "error" {
  count             = contains(var.enabled_cloudwatch_logs_exports, "error") ? 1 : 0
  name              = "/aws/rds/cluster/${var.cluster_identifier}/error"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "general" {
  count             = contains(var.enabled_cloudwatch_logs_exports, "general") ? 1 : 0
  name              = "/aws/rds/cluster/${var.cluster_identifier}/general"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "slowquery" {
  count             = contains(var.enabled_cloudwatch_logs_exports, "slowquery") ? 1 : 0
  name              = "/aws/rds/cluster/${var.cluster_identifier}/slowquery"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization" {
  count               = var.enable_cloudwatch_alarms ? var.instance_count : 0
  alarm_name          = "${var.cluster_identifier}-instance-${count.index + 1}-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "CPU utilization alarm for ${var.cluster_identifier}-instance-${count.index + 1}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.main[count.index].id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "database_connections" {
  count               = var.enable_cloudwatch_alarms ? var.instance_count : 0
  alarm_name          = "${var.cluster_identifier}-instance-${count.index + 1}-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.connection_alarm_threshold
  alarm_description   = "Database connections alarm for ${var.cluster_identifier}-instance-${count.index + 1}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.main[count.index].id
  }

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "freeable_memory" {
  count               = var.enable_cloudwatch_alarms ? var.instance_count : 0
  alarm_name          = "${var.cluster_identifier}-instance-${count.index + 1}-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = 268435456 # 256 MB in bytes
  alarm_description   = "Low memory alarm for ${var.cluster_identifier}-instance-${count.index + 1}"
  alarm_actions       = var.alarm_actions

  dimensions = {
    DBInstanceIdentifier = aws_rds_cluster_instance.main[count.index].id
  }

  tags = var.tags
}

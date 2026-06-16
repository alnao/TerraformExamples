# ====================================
# SECRETS MANAGER per RDS
# ====================================

resource "random_password" "rds_password" {
  count   = var.create_rds ? 1 : 0
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  count       = var.create_rds ? 1 : 0
  name        = "${var.project_name}-rds-credentials"
  description = "RDS credentials for ${var.project_name}"
  tags        = local.common_tags
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  count     = var.create_rds ? 1 : 0
  secret_id = aws_secretsmanager_secret.rds_credentials[0].id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.rds_password[0].result
    engine   = var.rds_engine
    host     = var.create_rds ? aws_rds_cluster.main[0].endpoint : ""
    port     = 3306
    database = var.rds_database_name
  })
}

# ====================================
# VPC DATA SOURCES
# ====================================

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ====================================
# VPC ENDPOINTS (solo Gateway, gratuiti)
# Permettono alla Lambda in VPC di raggiungere S3 e DynamoDB
# senza NAT Gateway. Le credenziali RDS vengono passate come
# variabili d'ambiente Lambda (criptate at-rest) per evitare
# il costo di un Interface Endpoint per Secrets Manager.
# ====================================

# S3 Gateway Endpoint (gratuito)
resource "aws_vpc_endpoint" "s3" {
  count        = var.create_rds ? 1 : 0
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.${var.region}.s3"

  tags = merge(local.common_tags, { Name = "${var.project_name}-s3-endpoint" })
}

# Associa il S3 endpoint alle route tables delle subnet
data "aws_route_tables" "default" {
  count  = var.create_rds ? 1 : 0
  vpc_id = data.aws_vpc.default.id
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  for_each = var.create_rds ? toset(data.aws_route_tables.default[0].ids) : toset([])

  route_table_id  = each.value
  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
}

# DynamoDB Gateway Endpoint (gratuito, per logging)
resource "aws_vpc_endpoint" "dynamodb" {
  count        = var.create_rds ? 1 : 0
  vpc_id       = data.aws_vpc.default.id
  service_name = "com.amazonaws.${var.region}.dynamodb"

  tags = merge(local.common_tags, { Name = "${var.project_name}-dynamodb-endpoint" })
}

resource "aws_vpc_endpoint_route_table_association" "dynamodb" {
  for_each = var.create_rds ? toset(data.aws_route_tables.default[0].ids) : toset([])

  route_table_id  = each.value
  vpc_endpoint_id = aws_vpc_endpoint.dynamodb[0].id
}

# ====================================
# SECURITY GROUPS
# ====================================

resource "aws_security_group" "rds" {
  count       = var.create_rds ? 1 : 0
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS Aurora"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda[0].id]
    description     = "MySQL from Lambda"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# Security Group per Lambda (per accesso RDS)
resource "aws_security_group" "lambda" {
  count       = var.create_rds ? 1 : 0
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ====================================
# RDS AURORA
# ====================================

resource "aws_db_subnet_group" "main" {
  count      = var.create_rds ? 1 : 0
  name       = "${var.project_name}-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.common_tags
}

resource "aws_rds_cluster" "main" {
  count              = var.create_rds ? 1 : 0
  cluster_identifier = "${var.project_name}-aurora"
  engine             = var.rds_engine
  engine_version     = var.rds_engine_version
  database_name      = var.rds_database_name
  master_username    = "admin"
  master_password    = random_password.rds_password[0].result

  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  backup_retention_period      = 7
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  skip_final_snapshot = var.rds_skip_final_snapshot
  storage_encrypted   = true

  tags = local.common_tags
}

resource "aws_rds_cluster_instance" "main" {
  count              = var.create_rds ? 1 : 0
  identifier         = "${var.project_name}-aurora-instance"
  cluster_identifier = aws_rds_cluster.main[0].id
  instance_class     = var.rds_instance_class
  engine             = aws_rds_cluster.main[0].engine
  engine_version     = aws_rds_cluster.main[0].engine_version

  tags = local.common_tags
}

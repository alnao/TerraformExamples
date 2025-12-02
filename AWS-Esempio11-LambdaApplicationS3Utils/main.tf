terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(
    var.tags,
    var.additional_tags,
    {
      Project = var.project_name
    }
  )
  
  dynamodb_scan_table_name = "${var.project_name}-${var.dynamodb_scan_suffix}"
}

# ====================================
# S3 BUCKET
# ====================================

resource "aws_s3_bucket" "main" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy_bucket
  tags          = local.common_tags
}

# Disabilita "Block all public access"
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy Custom
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPublicRead"
        Effect = "Allow"
        Principal = "*"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.main.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# Versioning (opzionale ma consigliato)
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

# EventBridge notification
resource "aws_s3_bucket_notification" "main" {
  bucket      = aws_s3_bucket.main.id
  eventbridge = true
}

# ====================================
# DYNAMODB TABLES
# ====================================

# Tabella Logs
resource "aws_dynamodb_table" "logs" {
  name           = var.dynamodb_logs_table_name
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "id"
  range_key      = "timestamp"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  attribute {
    name = "operation"
    type = "S"
  }

  global_secondary_index {
    name            = "OperationIndex"
    hash_key        = "operation"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

# Tabella Scan
resource "aws_dynamodb_table" "scan" {
  name         = local.dynamodb_scan_table_name
  billing_mode = var.dynamodb_billing_mode
  hash_key     = "file_key"

  attribute {
    name = "file_key"
    type = "S"
  }

  attribute {
    name = "scan_date"
    type = "S"
  }

  global_secondary_index {
    name            = "ScanDateIndex"
    hash_key        = "scan_date"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

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
# RDS AURORA
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

  skip_final_snapshot = true
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
# IAM ROLES E POLICIES
# ====================================

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

# Policy per S3
resource "aws_iam_role_policy" "lambda_s3" {
  name = "s3-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      }
    ]
  })
}

# Policy per DynamoDB
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.logs.arn,
          "${aws_dynamodb_table.logs.arn}/index/*",
          aws_dynamodb_table.scan.arn,
          "${aws_dynamodb_table.scan.arn}/index/*"
        ]
      }
    ]
  })
}

# Policy per Secrets Manager
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "secrets-manager-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.create_rds ? [aws_secretsmanager_secret.rds_credentials[0].arn] : []
      }
    ]
  })
}

# Policy per SSM Parameter Store (chiave privata SFTP)
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "ssm-access"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.region}:*:parameter${var.sftp_private_key_ssm_parameter}"
      }
    ]
  })
}

# Policy VPC (se RDS è abilitato)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.create_rds ? 1 : 0
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ====================================
# CLOUDWATCH LOG GROUPS
# ====================================

resource "aws_cloudwatch_log_group" "lambda_presigned_url" {
  name              = "/aws/lambda/${var.project_name}-presigned-url"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_extract_zip" {
  name              = "/aws/lambda/${var.project_name}-extract-zip"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_excel_to_csv" {
  name              = "/aws/lambda/${var.project_name}-excel-to-csv"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_upload_to_rds" {
  name              = "/aws/lambda/${var.project_name}-upload-to-rds"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_sftp_send" {
  name              = "/aws/lambda/${var.project_name}-sftp-send"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_s3_scan" {
  name              = "/aws/lambda/${var.project_name}-s3-scan"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_list_files" {
  name              = "/aws/lambda/${var.project_name}-list-files"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "lambda_search_files" {
  name              = "/aws/lambda/${var.project_name}-search-files"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

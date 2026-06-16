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
          "dynamodb:BatchWriteItem",
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
# Nota: quando create_rds = false la policy punta a un ARN placeholder non esistente,
# ma la policy stessa è comunque valida (IAM accetta ARN inesistenti nelle policy).
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
        Resource = var.create_rds ? [aws_secretsmanager_secret.rds_credentials[0].arn] : ["arn:aws:secretsmanager:${var.region}:*:secret:no-rds-placeholder"]
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

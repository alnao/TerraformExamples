# ====================================
# SEGRETI DELL'APPLICAZIONE
# Il profilo "prod" dell'immagine rifiuta di partire con i segreti di default
# (StartupSecretsGuard): vengono generati casualmente e salvati su
# SSM Parameter Store come SecureString. L'istanza li legge all'avvio,
# cosi' non compaiono in chiaro nello user data.
# ====================================

resource "random_password" "db" {
  length  = 24
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 48
  special = false
}

resource "random_password" "banned_subject_pepper" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name        = "${local.ssm_prefix}/db-password"
  description = "Password del database PostgreSQL di Paths Games (esempio 20)"
  type        = "SecureString"
  value       = random_password.db.result

  tags = merge(local.common_tags, { Name = "aws-esempio20.ssm-db-password" })
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "${local.ssm_prefix}/jwt-secret"
  description = "JWT_SECRET di Paths Games (esempio 20)"
  type        = "SecureString"
  value       = random_password.jwt_secret.result

  tags = merge(local.common_tags, { Name = "aws-esempio20.ssm-jwt-secret" })
}

resource "aws_ssm_parameter" "banned_subject_pepper" {
  name        = "${local.ssm_prefix}/banned-subject-pepper"
  description = "BANNED_SUBJECT_PEPPER di Paths Games (esempio 20)"
  type        = "SecureString"
  value       = random_password.banned_subject_pepper.result

  tags = merge(local.common_tags, { Name = "aws-esempio20.ssm-banned-subject-pepper" })
}

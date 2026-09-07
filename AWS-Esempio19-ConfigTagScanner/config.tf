# ====================================
# AWS CONFIG - IL MOTORE DELL'ESEMPIO
#
#   configuration recorder  registra com'e' fatta ogni risorsa e i suoi tag
#     -> delivery channel   consegna cronologia e snapshot sul bucket S3
#       -> config rule      valuta ogni risorsa registrata
#         -> compliance     COMPLIANT / NON_COMPLIANT, per risorsa
#
# ⚠️ AWS ammette UN SOLO configuration recorder per regione per account:
# se e' gia' attivo (per esempio da Security Hub o Control Tower) va messo
# create_config_recorder = false, la regola funziona lo stesso.
# ====================================

# ---- Ruolo assunto dal servizio Config ----
resource "aws_iam_role" "config" {
  name = "${var.project_name}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = local.common_tags
}

# Politica gestita da AWS: permessi di sola lettura su tutti i servizi
# da inventariare, piu' la scrittura sul bucket di consegna.
resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  name = "delivery-bucket"
  role = aws_iam_role.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetBucketAcl"]
        Resource = aws_s3_bucket.config.arn
      },
    ]
  })
}

# ---- Configuration recorder ----
resource "aws_config_configuration_recorder" "main" {
  count = var.create_config_recorder ? 1 : 0

  name     = "${var.project_name}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = var.record_all_resources
    include_global_resource_types = false
    resource_types                = var.record_all_resources ? null : var.recorded_resource_types
  }
}

# ---- Delivery channel ----
resource "aws_config_delivery_channel" "main" {
  count = var.create_config_recorder ? 1 : 0

  name           = "${var.project_name}-channel"
  s3_bucket_name = aws_s3_bucket.config.id

  snapshot_delivery_properties {
    delivery_frequency = var.delivery_frequency
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# ---- Accensione della registrazione ----
# Il recorder nasce spento: finche' non e' avviato nessuna regola valuta nulla.
resource "aws_config_configuration_recorder_status" "main" {
  count = var.create_config_recorder ? 1 : 0

  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# ====================================
# LA REGOLA NATIVA REQUIRED_TAGS
#
# E' una regola gestita da AWS: nessuna Lambda da scrivere, si passano solo
# i parametri tag1Key..tag6Key (e i valori ammessi, facoltativi).
# Una risorsa e' NON_COMPLIANT se le manca anche un solo tag richiesto
# o se il valore non e' fra quelli ammessi.
# ====================================

resource "aws_config_config_rule" "required_tags" {
  name        = local.rule_name
  description = "Verifica che ogni risorsa abbia i tag ${join(", ", local.tag_keys)}"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode(local.parametri_regola)

  scope {
    compliance_resource_types = var.compliance_resource_types
  }

  tags = local.common_tags

  # Senza recorder attivo la regola viene creata ma resta senza valutazioni
  depends_on = [aws_config_configuration_recorder_status.main]
}

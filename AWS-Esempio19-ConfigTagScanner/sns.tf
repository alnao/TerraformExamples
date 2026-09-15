# ====================================
# SNS + EVENTBRIDGE - NOTIFICA DELLE RISORSE NON CONFORMI
#
# AWS Config pubblica su EventBridge un evento "Config Rules Compliance Change"
# ogni volta che una risorsa cambia stato di conformita', sul bus di default
# DELLA REGIONE della risorsa. SNS non puo' essere bersaglio cross-region,
# quindi:
#   - ogni regione (modulo) inoltra i NON_COMPLIANT al bus della regione centrale
#   - la regola qui sotto, sulla regione centrale, li manda su SNS
#     (vale sia per gli eventi locali sia per quelli inoltrati)
# ====================================

resource "aws_sns_topic" "non_compliant" {
  name = local.sns_topic_name
  tags = local.common_tags
}

resource "aws_sns_topic_policy" "non_compliant" {
  arn = aws_sns_topic.non_compliant.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.non_compliant.arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.non_compliant.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ---- Ruolo con cui le regole delle altre regioni scrivono sul bus centrale ----
# Per un bus dello stesso account non serve una policy sul bus: basta che la
# regola abbia un ruolo con events:PutEvents sul bus di destinazione.
resource "aws_iam_role" "eventbridge_forward" {
  count = var.enable_eventbridge_notification ? 1 : 0

  name = "${var.project_name}-eventbridge-forward"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "eventbridge_forward" {
  count = var.enable_eventbridge_notification ? 1 : 0

  name = "put-events-central-bus"
  role = aws_iam_role.eventbridge_forward[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = local.central_bus_arn
    }]
  })
}

# ---- Regola centrale: NON_COMPLIANT (locali e inoltrati) -> SNS ----
resource "aws_cloudwatch_event_rule" "non_compliant" {
  count = var.enable_eventbridge_notification ? 1 : 0

  name        = "${var.project_name}-non-compliant"
  description = "Risorse diventate NON_COMPLIANT per le regole ${join(", ", local.rule_names)}, da tutte le regioni"

  # Gli eventi inoltrati da un'altra regione conservano source, detail-type
  # e detail: lo stesso pattern vale per entrambi.
  event_pattern = jsonencode({
    source      = ["aws.config"]
    detail-type = ["Config Rules Compliance Change"]
    detail = {
      configRuleName = local.rule_names
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })

  tags = local.common_tags
}

# L'input transformer trasforma l'evento in una frase leggibile:
# senza, la mail sarebbe il JSON grezzo dell'evento.
resource "aws_cloudwatch_event_target" "sns" {
  count = var.enable_eventbridge_notification ? 1 : 0

  rule      = aws_cloudwatch_event_rule.non_compliant[0].name
  target_id = "sns"
  arn       = aws_sns_topic.non_compliant.arn

  input_transformer {
    input_paths = {
      tipo    = "$.detail.resourceType"
      risorsa = "$.detail.resourceId"
      regola  = "$.detail.configRuleName"
      istante = "$.detail.newEvaluationResult.resultRecordedTime"
      regione = "$.detail.awsRegion"
    }

    input_template = <<-TEMPLATE
      "Risorsa non conforme ai tag obbligatori."
      "Tipo: <tipo>"
      "Risorsa: <risorsa>"
      "Regola: <regola>"
      "Regione: <regione>"
      "Rilevata il: <istante>"
    TEMPLATE
  }
}

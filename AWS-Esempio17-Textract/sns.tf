# ====================================
# SNS - CANALE DI NOTIFICA DEI JOB TEXTRACT ASINCRONI (PDF)
#
# I PDF non possono passare dalle operazioni sincrone di Textract, che
# accettano una sola pagina. Si usano quindi StartDocumentAnalysis /
# StartDocumentTextDetection, che restituiscono subito un JobId e pubblicano
# un messaggio su questo topic quando il lavoro e' finito.
#
#   textract_analyze --Start*--> Textract --SNS--> textract_collect --Get*-->
#
# Textract non pubblica con i permessi di chi lo ha invocato: assume il ruolo
# indicato in NotificationChannel.RoleArn, che e' quello definito qui sotto.
# ====================================

resource "aws_sns_topic" "textract" {
  name = local.sns_topic_name
  tags = local.common_tags
}

# ---- Ruolo assunto da Textract per pubblicare sul topic ----
resource "aws_iam_role" "textract_sns" {
  name = "${var.project_name}-textract-sns-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "textract.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "textract_sns" {
  name = "sns-publish"
  role = aws_iam_role.textract_sns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.textract.arn
    }]
  })
}

# ---- Il topic invoca la lambda che raccoglie i risultati ----
resource "aws_sns_topic_subscription" "textract_collect" {
  topic_arn = aws_sns_topic.textract.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.textract_collect.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.textract_collect.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.textract.arn
}

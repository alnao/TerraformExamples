# ====================================
# SNS - DESTINAZIONE DELLE NOTIFICHE DELL'ALLARME
#
# La policy serve a CloudWatch per pubblicare sul topic:
# senza di essa l'allarme cambia stato ma nessuno riceve nulla.
# ====================================

resource "aws_sns_topic" "errors" {
  name = local.sns_topic_name
  tags = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_sns_topic_policy" "errors" {
  arn = aws_sns_topic.errors.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudwatch.amazonaws.com"
      }
      Action   = "sns:Publish"
      Resource = aws_sns_topic.errors.arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

# L'iscrizione via email va confermata dal destinatario:
# fino al click sul link di conferma non arriva nessuna notifica.
resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.errors.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ====================================
# LAMBDA ISCRITTA AL TOPIC
#
# La mail di SNS arriva comunque; in piu' questa Lambda intercetta la stessa
# notifica, la traduce in una riga leggibile e la salva su DynamoDB.
# ====================================

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.errors.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_to_dynamo.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_to_dynamo.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.errors.arn
}

output "lambda_function_name" {
  description = "Nome della Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "ARN della Lambda function"
  value       = aws_lambda_function.main.arn
}

output "dynamodb_table_name" {
  description = "Nome della tabella DynamoDB"
  value       = aws_dynamodb_table.logs.name
}

output "dynamodb_table_arn" {
  description = "ARN della tabella DynamoDB"
  value       = aws_dynamodb_table.logs.arn
}

output "sqs_queue_name" {
  description = "Nome della coda SQS"
  value       = aws_sqs_queue.main.name
}

output "sqs_queue_url" {
  description = "URL della coda SQS"
  value       = aws_sqs_queue.main.id
}

output "sqs_queue_arn" {
  description = "ARN della coda SQS"
  value       = aws_sqs_queue.main.arn
}

output "sns_topic_name" {
  description = "Nome del topic SNS"
  value       = aws_sns_topic.main.name
}

output "sns_topic_arn" {
  description = "ARN del topic SNS"
  value       = aws_sns_topic.main.arn
}

output "sns_email_subscription" {
  description = "Email configurata per la ricezione delle notifiche (se definita)"
  value       = var.notification_email != "" ? var.notification_email : "Nessuna mail configurata"
}

output "test_aws_cli_invoke" {
  description = "Comando AWS CLI per invocare la Lambda manualmente"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.main.function_name} --payload '{\"message\": \"Ciao da AlNao! Questo è un test.\", \"sender\": \"AlNao\"}' --cli-binary-format raw-in-base64-out response.json"
}

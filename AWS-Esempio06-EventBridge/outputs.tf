output "source_bucket_name" {
  description = "Nome del bucket S3 sorgente"
  value       = aws_s3_bucket.source.id
}

output "source_bucket_arn" {
  description = "ARN del bucket S3 sorgente"
  value       = aws_s3_bucket.source.arn
}

output "lambda_function_name" {
  description = "Nome della Lambda function"
  value       = aws_lambda_function.processor.function_name
}

output "lambda_function_arn" {
  description = "ARN della Lambda function"
  value       = aws_lambda_function.processor.arn
}

output "eventbridge_rule_name" {
  description = "Nome della EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_object_created.name
}

output "eventbridge_rule_arn" {
  description = "ARN della EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_object_created.arn
}

output "log_group_name" {
  description = "Nome del CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "dlq_url" {
  description = "URL della Dead Letter Queue"
  value       = var.create_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "test_upload_command" {
  description = "Comando per testare caricando un file"
  value       = "aws s3 cp test.txt s3://${aws_s3_bucket.source.id}/test.txt"
}

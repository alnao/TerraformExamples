output "lambda_function_name" {
  description = "Nome della Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "ARN della Lambda function"
  value       = aws_lambda_function.main.arn
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN della Lambda function"
  value       = aws_lambda_function.main.invoke_arn
}

output "lambda_function_version" {
  description = "Versione della Lambda function"
  value       = aws_lambda_function.main.version
}

output "lambda_role_arn" {
  description = "ARN del ruolo IAM della Lambda"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_function_url" {
  description = "Function URL (se abilitato)"
  value       = var.enable_function_url ? aws_lambda_function_url.main[0].function_url : null
}

output "bucket_name" {
  description = "Nome del bucket S3"
  value       = aws_s3_bucket.lambda_test.id
}

output "bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.lambda_test.arn
}

output "log_group_name" {
  description = "Nome del CloudWatch Log Group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "test_curl_command" {
  description = "Comando curl per testare la Lambda (se function URL è abilitato)"
  value       = var.enable_function_url ? "curl '${aws_lambda_function_url.main[0].function_url}?path=test/'" : "Function URL not enabled"
}

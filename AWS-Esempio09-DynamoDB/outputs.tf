output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.main.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.main.arn
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.main.id
}

output "stream_arn" {
  description = "ARN of the DynamoDB stream"
  value       = var.stream_enabled ? aws_dynamodb_table.main.stream_arn : null
}

output "stream_label" {
  description = "Stream label"
  value       = var.stream_enabled ? aws_dynamodb_table.main.stream_label : null
}

output "hash_key" {
  description = "Hash key attribute name"
  value       = aws_dynamodb_table.main.hash_key
}

output "range_key" {
  description = "Range key attribute name"
  value       = aws_dynamodb_table.main.range_key
}

output "billing_mode" {
  description = "Billing mode"
  value       = aws_dynamodb_table.main.billing_mode
}

output "replica_regions" {
  description = "List of replica regions"
  value       = var.replica_regions
}

# Lambda and S3 outputs
output "s3_bucket_name" {
  description = "Name of the S3 trigger bucket"
  value       = var.enable_s3_lambda_integration ? aws_s3_bucket.trigger_bucket[0].id : null
}

output "s3_bucket_arn" {
  description = "ARN of the S3 trigger bucket"
  value       = var.enable_s3_lambda_integration ? aws_s3_bucket.trigger_bucket[0].arn : null
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = var.enable_s3_lambda_integration ? aws_lambda_function.s3_to_dynamodb[0].function_name : null
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = var.enable_s3_lambda_integration ? aws_lambda_function.s3_to_dynamodb[0].arn : null
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = var.enable_s3_lambda_integration ? aws_cloudwatch_event_rule.s3_object_created[0].name : null
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule"
  value       = var.enable_s3_lambda_integration ? aws_cloudwatch_event_rule.s3_object_created[0].arn : null
}

output "test_upload_command" {
  description = "Command to test S3 upload triggering Lambda"
  value       = var.enable_s3_lambda_integration ? "echo 'test file' > /tmp/test.txt && aws s3 cp /tmp/test.txt s3://${aws_s3_bucket.trigger_bucket[0].id}/test.txt" : null
}

output "query_dynamodb_command" {
  description = "Command to query DynamoDB for uploaded files"
  value       = "aws dynamodb scan --table-name ${aws_dynamodb_table.main.name} --limit 10"
}

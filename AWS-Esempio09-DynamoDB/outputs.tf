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

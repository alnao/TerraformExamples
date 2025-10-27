output "api_id" {
  value = aws_api_gateway_rest_api.main.id
}

output "api_endpoint" {
  value = aws_api_gateway_stage.main.invoke_url
}

output "get_files_url" {
  value = "${aws_api_gateway_stage.main.invoke_url}/files"
}

output "post_calculate_url" {
  value = "${aws_api_gateway_stage.main.invoke_url}/calculate"
}

output "bucket_name" {
  value = aws_s3_bucket.files.id
}

output "test_get_command" {
  value = "curl ${aws_api_gateway_stage.main.invoke_url}/files"
}

output "test_post_command" {
  value = "curl -X POST ${aws_api_gateway_stage.main.invoke_url}/calculate -H 'Content-Type: application/json' -d '{\"cateto_a\":3,\"cateto_b\":4}'"
}

output "api_key" {
  value     = var.api_key_required ? aws_api_gateway_api_key.main[0].value : null
  sensitive = true
}

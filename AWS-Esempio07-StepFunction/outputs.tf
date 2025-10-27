output "source_bucket_name" {
  value = aws_s3_bucket.source.id
}

output "destination_bucket_name" {
  value = aws_s3_bucket.destination.id
}

output "step_function_arn" {
  value = aws_sfn_state_machine.main.arn
}

output "step_function_name" {
  value = aws_sfn_state_machine.main.name
}

output "logger_function_arn" {
  value = aws_lambda_function.logger.arn
}

output "test_command" {
  value = "aws s3 cp test.txt s3://${aws_s3_bucket.source.id}/test.txt"
}

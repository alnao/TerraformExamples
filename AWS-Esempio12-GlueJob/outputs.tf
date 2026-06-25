output "bucket_name" {
  description = "Nome bucket S3"
  value       = aws_s3_bucket.main.id
}

output "step_function_arn" {
  description = "ARN Step Function"
  value       = aws_sfn_state_machine.main.arn
}

output "step_function_name" {
  description = "Nome Step Function"
  value       = aws_sfn_state_machine.main.name
}

output "glue_job_name" {
  description = "Nome Glue Job"
  value       = aws_glue_job.main.name
}

output "excel2csv_lambda_name" {
  description = "Nome Lambda excel2csv"
  value       = aws_lambda_function.excel2csv.function_name
}

output "start_process_lambda_name" {
  description = "Nome Lambda start_process"
  value       = aws_lambda_function.start_process.function_name
}

output "upload_test_command" {
  description = "Comando esempio per trigger workflow"
  value       = "aws s3 cp ./persone.xlsx s3://${aws_s3_bucket.main.id}/${var.source_path}/persone.xlsx"
}

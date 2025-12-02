output "s3_bucket_name" {
  description = "Nome del bucket S3"
  value       = aws_s3_bucket.main.id
}

output "s3_bucket_arn" {
  description = "ARN del bucket S3"
  value       = aws_s3_bucket.main.arn
}

output "dynamodb_logs_table_name" {
  description = "Nome tabella DynamoDB per i log"
  value       = aws_dynamodb_table.logs.name
}

output "dynamodb_scan_table_name" {
  description = "Nome tabella DynamoDB per la scansione file"
  value       = aws_dynamodb_table.scan.name
}

output "rds_cluster_endpoint" {
  description = "Endpoint del cluster RDS"
  value       = var.create_rds ? aws_rds_cluster.main[0].endpoint : "RDS not created"
}

output "rds_database_name" {
  description = "Nome del database RDS"
  value       = var.create_rds ? aws_rds_cluster.main[0].database_name : "RDS not created"
}

output "rds_secret_arn" {
  description = "ARN del secret con le credenziali RDS"
  value       = var.create_rds ? aws_secretsmanager_secret.rds_credentials[0].arn : "RDS not created"
  sensitive   = true
}

output "api_gateway_url" {
  description = "URL base dell'API Gateway"
  value       = "${aws_api_gateway_stage.main.invoke_url}"
}

output "api_endpoints" {
  description = "Endpoint API disponibili"
  value = {
    presigned_url = "${aws_api_gateway_stage.main.invoke_url}/presigned-url"
    extract_zip   = "${aws_api_gateway_stage.main.invoke_url}/extract-zip"
    excel_to_csv  = "${aws_api_gateway_stage.main.invoke_url}/excel-to-csv"
    upload_to_rds = "${aws_api_gateway_stage.main.invoke_url}/upload-to-rds"
    sftp_send     = "${aws_api_gateway_stage.main.invoke_url}/sftp-send"
    list_files    = "${aws_api_gateway_stage.main.invoke_url}/files"
    search_files  = "${aws_api_gateway_stage.main.invoke_url}/files/search"
  }
}

output "lambda_functions" {
  description = "Nome delle Lambda functions create"
  value = {
    presigned_url = aws_lambda_function.presigned_url.function_name
    extract_zip   = aws_lambda_function.extract_zip.function_name
    excel_to_csv  = aws_lambda_function.excel_to_csv.function_name
    upload_to_rds = aws_lambda_function.upload_to_rds.function_name
    sftp_send     = aws_lambda_function.sftp_send.function_name
    s3_scan       = aws_lambda_function.s3_scan.function_name
    list_files    = aws_lambda_function.list_files.function_name
    search_files  = aws_lambda_function.search_files.function_name
  }
}

output "sftp_private_key_parameter" {
  description = "Nome del parametro SSM per la chiave privata SFTP"
  value       = var.sftp_private_key_ssm_parameter
}

output "sns_topic_arn" {
  description = "ARN del topic SNS per gli allarmi"
  value       = var.alarm_email != "" ? aws_sns_topic.alarms[0].arn : "SNS topic not created"
}

output "project_tags" {
  description = "Tag applicati alle risorse"
  value       = local.common_tags
}

output "instructions" {
  description = "Istruzioni per il setup iniziale"
  value = <<-EOT
    
    ========================================
    Setup Iniziale - Esempio 11
    ========================================
    
    1. Crea la chiave privata SFTP in SSM Parameter Store:
       
       # Genera chiave RSA
       ssh-keygen -t rsa -b 2048 -f sftp_key -N ""
       
       # Carica in SSM Parameter Store
       aws ssm put-parameter \
         --name "${var.sftp_private_key_ssm_parameter}" \
         --value "file://sftp_key" \
         --type "SecureString" \
         --region ${var.region}
    
    2. Test API Gateway:
       
       # Genera presigned URL
       curl -X POST ${aws_api_gateway_stage.main.invoke_url}/presigned-url \
         -H "Content-Type: application/json" \
         -d '{"filename": "test.txt"}'
       
       # Lista file
       curl ${aws_api_gateway_stage.main.invoke_url}/files
       
       # Cerca file
       curl "${aws_api_gateway_stage.main.invoke_url}/files/search?name=test"
    
    3. Verifica RDS (se creato):
       
       aws secretsmanager get-secret-value \
         --secret-id ${var.create_rds ? aws_secretsmanager_secret.rds_credentials[0].arn : "RDS_SECRET_ARN"} \
         --query SecretString \
         --output text | jq .
    
    4. Conferma subscription SNS (se email specificata):
       Controlla la tua email per confermare la subscription
    
    ========================================
  EOT
}

# ====================================
# OUTPUT
# ====================================

output "website_url" {
  description = "URL del sito statico con le due pagine (upload e lista)"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "website_lista_url" {
  description = "URL diretto della pagina con la tabella dei risultati"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}/lista.html"
}

output "api_endpoint" {
  description = "Base URL della REST API"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "upload_url_endpoint" {
  description = "Endpoint POST che genera il presigned URL di upload"
  value       = "${aws_api_gateway_stage.main.invoke_url}/upload-url"
}

output "images_endpoint" {
  description = "Endpoint GET con l'elenco delle immagini analizzate"
  value       = "${aws_api_gateway_stage.main.invoke_url}/images"
}

output "bucket_name" {
  description = "Bucket S3 delle immagini"
  value       = aws_s3_bucket.images.id
}

output "website_bucket_name" {
  description = "Bucket S3 del sito statico"
  value       = aws_s3_bucket.website.id
}

output "table_name" {
  description = "Tabella DynamoDB con i risultati di Rekognition"
  value       = aws_dynamodb_table.images.name
}

output "keyword_rilevante" {
  description = "Parola chiave che marca una immagine come rilevante"
  value       = var.keyword_rilevante
}

output "lambda_detect_labels_name" {
  value = aws_lambda_function.detect_labels.function_name
}

output "lambda_presigned_url_name" {
  value = aws_lambda_function.presigned_url.function_name
}

output "lambda_list_images_name" {
  value = aws_lambda_function.list_images.function_name
}

# ---- Comandi di test pronti all'uso ----

output "test_upload_cli" {
  description = "Carica una immagine da CLI e fa partire l'analisi"
  value       = "aws s3 cp ./aereo.jpg s3://${aws_s3_bucket.images.id}/${var.input_prefix} --region ${var.region}"
}

output "test_list_all" {
  description = "Elenco di tutte le immagini analizzate"
  value       = "curl -s '${aws_api_gateway_stage.main.invoke_url}/images'"
}

output "test_list_rilevanti" {
  description = "Elenco delle sole immagini rilevanti"
  value       = "curl -s '${aws_api_gateway_stage.main.invoke_url}/images?rilevanti=true'"
}

output "test_cors_preflight" {
  description = "Verifica del preflight CORS sull'endpoint di upload"
  value       = "curl -i -X OPTIONS '${aws_api_gateway_stage.main.invoke_url}/upload-url'"
}

output "test_logs" {
  description = "Log in tempo reale della lambda di analisi"
  value       = "aws logs tail /aws/lambda/${aws_lambda_function.detect_labels.function_name} --follow --region ${var.region}"
}

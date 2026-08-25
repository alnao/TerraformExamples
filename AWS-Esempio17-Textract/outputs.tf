# ====================================
# OUTPUT
# ====================================

output "website_url" {
  description = "URL del sito statico con le due pagine (upload e lista)"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "website_lista_url" {
  description = "URL diretto della pagina con l'elenco dei documenti analizzati"
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

output "documents_endpoint" {
  description = "Endpoint GET con l'elenco dei documenti e il testo estratto"
  value       = "${aws_api_gateway_stage.main.invoke_url}/documents"
}

output "bucket_name" {
  description = "Bucket S3 dei documenti (input/, output/, output-raw/, jobs/)"
  value       = aws_s3_bucket.docs.id
}

output "website_bucket_name" {
  description = "Bucket S3 del sito statico"
  value       = aws_s3_bucket.website.id
}

output "input_prefix" {
  description = "Cartella del bucket monitorata dalla Lambda di analisi"
  value       = var.input_prefix
}

output "output_prefix" {
  description = "Cartella del bucket con i JSON del testo estratto"
  value       = var.output_prefix
}

output "lambda_textract_analyze_name" {
  value = aws_lambda_function.textract_analyze.function_name
}

output "lambda_textract_collect_name" {
  value = aws_lambda_function.textract_collect.function_name
}

output "lambda_presigned_url_name" {
  value = aws_lambda_function.presigned_url.function_name
}

output "lambda_list_documents_name" {
  value = aws_lambda_function.list_documents.function_name
}

output "sns_topic_arn" {
  description = "Topic SNS su cui Textract notifica la fine dei job asincroni (PDF)"
  value       = aws_sns_topic.textract.arn
}

output "textract_api_default" {
  description = "Operazioni Textract usate dagli upload che non specificano opzioni"
  value = length(var.default_feature_types) > 0 ? join(" / ", [
    "immagini: AnalyzeDocument (${join(", ", var.default_feature_types)})",
    "pdf: StartDocumentAnalysis (${join(", ", var.default_feature_types)})"
    ]) : join(" / ", [
    "immagini: DetectDocumentText",
    "pdf: StartDocumentTextDetection"
  ])
}

# ---- Comandi di test pronti all'uso ----

output "test_upload_cli" {
  description = "Carica una immagine da CLI e fa partire l'analisi sincrona con le opzioni di default"
  value       = "aws s3 cp ./documento.png s3://${aws_s3_bucket.docs.id}/${var.input_prefix} --region ${var.region}"
}

output "test_upload_pdf_cli" {
  description = "Carica un PDF da CLI e fa partire il job Textract asincrono"
  value       = "aws s3 cp ./documento.pdf s3://${aws_s3_bucket.docs.id}/${var.input_prefix} --region ${var.region}"
}

output "test_logs_collect" {
  description = "Log in tempo reale della lambda che raccoglie i risultati dei PDF"
  value       = "aws logs tail /aws/lambda/${aws_lambda_function.textract_collect.function_name} --follow --region ${var.region}"
}

output "test_list_all" {
  description = "Elenco di tutti i documenti caricati"
  value       = "curl -s '${aws_api_gateway_stage.main.invoke_url}/documents' | jq"
}

output "test_list_completati" {
  description = "Elenco dei soli documenti gia' elaborati da Textract"
  value       = "curl -s '${aws_api_gateway_stage.main.invoke_url}/documents?stato=completati' | jq"
}

output "test_upload_url_queries" {
  description = "Richiesta di un presigned URL con feature TABLES e una query"
  value       = "curl -s -X POST '${aws_api_gateway_stage.main.invoke_url}/upload-url' -H 'Content-Type: application/json' -d '{\"filename\":\"fattura.png\",\"content_type\":\"image/png\",\"feature_types\":[\"TABLES\"],\"queries\":[{\"text\":\"Qual e il totale?\",\"alias\":\"totale\"}]}' | jq"
}

output "test_json_risultato" {
  description = "Scarica il JSON prodotto per un documento (sostituire il nome file)"
  value       = "aws s3 cp s3://${aws_s3_bucket.docs.id}/${var.output_prefix}NOME-FILE.png.json - --region ${var.region} | jq"
}

output "test_cors_preflight" {
  description = "Verifica del preflight CORS sull'endpoint di upload"
  value       = "curl -i -X OPTIONS '${aws_api_gateway_stage.main.invoke_url}/upload-url'"
}

output "test_logs" {
  description = "Log in tempo reale della lambda di analisi"
  value       = "aws logs tail /aws/lambda/${aws_lambda_function.textract_analyze.function_name} --follow --region ${var.region}"
}

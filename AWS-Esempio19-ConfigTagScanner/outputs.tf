output "config_rule_name" {
  description = "Nome della regola AWS Config che verifica i tag"
  value       = aws_config_config_rule.required_tags.name
}

output "config_rule_arn" {
  description = "ARN della regola"
  value       = aws_config_config_rule.required_tags.arn
}

output "required_tag_keys" {
  description = "Tag obbligatori verificati dalla regola"
  value       = local.tag_keys
}

output "rule_parameters" {
  description = "Parametri passati alla regola nativa REQUIRED_TAGS"
  value       = local.parametri_regola
}

output "config_bucket_name" {
  description = "Bucket dove AWS Config consegna snapshot e cronologia"
  value       = aws_s3_bucket.config.id
}

output "sns_topic_arn" {
  description = "ARN del topic SNS che riceve le risorse non conformi"
  value       = aws_sns_topic.non_compliant.arn
}

output "demo_bucket_compliant" {
  description = "Bucket di prova con tutti i tag richiesti"
  value       = var.create_demo_resources ? aws_s3_bucket.demo_ok[0].id : null
}

output "demo_bucket_non_compliant" {
  description = "Bucket di prova a cui mancano dei tag"
  value       = var.create_demo_resources ? aws_s3_bucket.demo_ko[0].id : null
}

output "console_url" {
  description = "Pagina della regola nella console AWS Config"
  value       = "https://${var.region}.console.aws.amazon.com/config/home?region=${var.region}#/rules/details?configRuleName=${aws_config_config_rule.required_tags.name}"
}

output "comando_scansione" {
  description = "Script che elenca le risorse non conformi"
  value       = "./scansione.sh -t"
}

output "website_url" {
  description = "Cruscotto web con le risorse conformi e non conformi"
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}

output "api_url" {
  description = "Endpoint GET /compliance dell'API Gateway"
  value       = "${aws_api_gateway_stage.main.invoke_url}/compliance"
}

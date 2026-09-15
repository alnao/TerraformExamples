output "regions" {
  description = "Regioni in cui sono attivi recorder e regola"
  value       = var.regions
}

output "home_region" {
  description = "Regione centrale: aggregator, SNS, Lambda, API e sito"
  value       = var.home_region
}

output "config_rule_name" {
  description = "Nome della regola nativa REQUIRED_TAGS (uguale in tutte le regioni; null con custom_rule_only)"
  value       = local.enable_native_rule ? local.rule_name : null
}

output "custom_rule_name" {
  description = "Nome della regola custom Guard (null se disattivata)"
  value       = local.enable_custom_rule ? local.custom_rule_name : null
}

output "config_rule_names" {
  description = "Tutte le regole che verificano i tag: le legge scansione.sh"
  value       = local.rule_names
}

output "config_rule_arns" {
  description = "ARN della regola nativa, per regione"
  value       = { for r, m in local.region_modules : r => m.rule_arn }
}

output "custom_rule_arns" {
  description = "ARN della regola custom, per regione"
  value       = { for r, m in local.region_modules : r => m.custom_rule_arn }
}

output "custom_rule_policy" {
  description = "Policy Guard generata per la regola custom"
  value       = local.enable_custom_rule ? local.custom_rule_policy : null
}

output "aggregator_name" {
  description = "Configuration aggregator che riunisce le valutazioni di tutte le regioni"
  value       = aws_config_configuration_aggregator.main.name
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
  description = "Bucket unico dove AWS Config di tutte le regioni consegna snapshot e cronologia"
  value       = aws_s3_bucket.config.id
}

output "sns_topic_arn" {
  description = "ARN del topic SNS che riceve le risorse non conformi"
  value       = aws_sns_topic.non_compliant.arn
}

output "demo_buckets_compliant" {
  description = "Bucket di prova con tutti i tag richiesti, per regione"
  value       = { for r, m in local.region_modules : r => m.demo_bucket_compliant }
}

output "demo_buckets_non_compliant" {
  description = "Bucket di prova a cui mancano dei tag, per regione"
  value       = { for r, m in local.region_modules : r => m.demo_bucket_non_compliant }
}

output "console_urls" {
  description = "Pagina della regola nella console AWS Config, per regione"
  value       = { for r, m in local.region_modules : r => m.console_url }
}

output "aggregator_console_url" {
  description = "Vista aggregata di tutte le regioni nella console AWS Config"
  value       = "https://${var.home_region}.console.aws.amazon.com/config/home?region=${var.home_region}#/aggregators/details?aggregatorName=${aws_config_configuration_aggregator.main.name}"
}

output "comando_scansione" {
  description = "Script che elenca le risorse non conformi di tutte le regioni"
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

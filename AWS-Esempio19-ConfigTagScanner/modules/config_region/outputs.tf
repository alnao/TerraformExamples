output "region" {
  value = var.region
}

output "rule_name" {
  value = var.settings.enable_native_rule ? aws_config_config_rule.required_tags[0].name : null
}

output "rule_arn" {
  value = var.settings.enable_native_rule ? aws_config_config_rule.required_tags[0].arn : null
}

output "custom_rule_name" {
  value = var.settings.enable_custom_rule ? aws_config_config_rule.required_tags_custom[0].name : null
}

output "custom_rule_arn" {
  value = var.settings.enable_custom_rule ? aws_config_config_rule.required_tags_custom[0].arn : null
}

output "recorder_name" {
  value = var.settings.create_recorder ? aws_config_configuration_recorder.main[0].name : null
}

output "demo_bucket_compliant" {
  value = var.settings.create_demo_resources ? aws_s3_bucket.demo_ok[0].id : null
}

output "demo_bucket_non_compliant" {
  value = var.settings.create_demo_resources ? aws_s3_bucket.demo_ko[0].id : null
}

output "console_url" {
  value = "https://${var.region}.console.aws.amazon.com/config/home?region=${var.region}#/rules/details?configRuleName=${var.settings.enable_native_rule ? aws_config_config_rule.required_tags[0].name : aws_config_config_rule.required_tags_custom[0].name}"
}

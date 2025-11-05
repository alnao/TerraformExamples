output "resource_group_name" {
  description = "Nome del Resource Group"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "Nome dello Storage Account"
  value       = azurerm_storage_account.website.name
}

output "primary_web_endpoint" {
  description = "Endpoint primario del sito web"
  value       = azurerm_storage_account.website.primary_web_endpoint
}

output "primary_web_host" {
  description = "Host primario del sito web"
  value       = azurerm_storage_account.website.primary_web_host
}

output "website_url" {
  description = "URL completo del sito web"
  value       = "https://${azurerm_storage_account.website.primary_web_host}"
}

output "cdn_endpoint_url" {
  description = "URL del CDN endpoint (se abilitato)"
  value       = var.enable_cdn ? "https://${azurerm_cdn_endpoint.website[0].fqdn}" : null
}

output "cdn_custom_domain_url" {
  description = "URL del custom domain (se configurato)"
  value       = var.enable_cdn && var.custom_domain_name != "" ? "https://${var.custom_domain_name}" : null
}

output "storage_account_id" {
  description = "ID dello Storage Account"
  value       = azurerm_storage_account.website.id
}

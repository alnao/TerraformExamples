output "resource_group_name" {
  description = "Nome del Resource Group"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "Nome dello Storage Account"
  value       = azurerm_storage_account.origin.name
}

output "frontdoor_id" {
  description = "ID del Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.main.id
}

output "frontdoor_endpoint_hostname" {
  description = "Hostname dell'endpoint Front Door"
  value       = azurerm_cdn_frontdoor_endpoint.main.host_name
}

output "frontdoor_url" {
  description = "URL completo del Front Door"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.main.host_name}"
}

output "custom_domain_url" {
  description = "URL del custom domain (se configurato)"
  value       = var.custom_domain_name != "" ? "https://${var.custom_domain_name}" : null
}

output "origin_hostname" {
  description = "Hostname dell'origin (Storage Account)"
  value       = azurerm_storage_account.origin.primary_web_host
}

output "frontdoor_sku" {
  description = "SKU del Front Door"
  value       = azurerm_cdn_frontdoor_profile.main.sku_name
}

output "waf_policy_id" {
  description = "ID della WAF policy (se abilitata)"
  value       = var.enable_waf && var.frontdoor_sku == "Premium_AzureFrontDoor" ? azurerm_cdn_frontdoor_firewall_policy.main[0].id : null
}

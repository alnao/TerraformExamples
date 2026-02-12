output "logic_app_id" {
  value       = azurerm_logic_app_workflow.main.id
  description = "ID della Logic App"
}

output "logic_app_url" {
  value       = "https://portal.azure.com/#@/resource${azurerm_logic_app_workflow.main.id}"
  description = "URL del portale Azure per la Logic App"
}

output "function_app_name" {
  value       = azurerm_linux_function_app.main.name
  description = "Nome della Function App"
}

output "function_app_url" {
  value       = "https://${azurerm_linux_function_app.main.default_hostname}"
  description = "URL della Function App"
}

output "function_app_default_key" {
  value       = azurerm_linux_function_app.main.site_credential[0].name
  description = "Default hostname della Function App per la chiave"
  sensitive   = true
}

output "source_storage_name" {
  value       = azurerm_storage_account.source.name
  description = "Nome dello storage account di origine"
}

output "destination_storage_name" {
  value       = azurerm_storage_account.destination.name
  description = "Nome dello storage account di destinazione"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Nome del resource group"
}

output "application_insights_name" {
  value       = azurerm_application_insights.main.name
  description = "Nome di Application Insights"
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.main.id
  description = "ID del Log Analytics Workspace"
}

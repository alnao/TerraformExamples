output "resource_group_name" {
  description = "Nome del resource group"
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Nome della Function App"
  value       = var.function_app_name
}

output "function_app_id" {
  description = "ID della Function App"
  value       = var.os_type == "Linux" ? azurerm_linux_function_app.main[0].id : azurerm_windows_function_app.main[0].id
}

output "function_app_hostname" {
  description = "Hostname della Function App"
  value       = var.os_type == "Linux" ? azurerm_linux_function_app.main[0].default_hostname : azurerm_windows_function_app.main[0].default_hostname
}

output "function_app_url" {
  description = "URL della Function App"
  value       = "https://${var.os_type == "Linux" ? azurerm_linux_function_app.main[0].default_hostname : azurerm_windows_function_app.main[0].default_hostname}/api/list-blobs"
}

output "test_storage_account_name" {
  description = "Nome dello storage account di test"
  value       = azurerm_storage_account.test.name
}

output "test_container_name" {
  description = "Nome del container di test"
  value       = azurerm_storage_container.test.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key di Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}

output "application_insights_app_id" {
  description = "App ID di Application Insights"
  value       = azurerm_application_insights.main.app_id
}

output "managed_identity_principal_id" {
  description = "Principal ID della Managed Identity"
  value       = var.enable_managed_identity ? (var.os_type == "Linux" ? azurerm_linux_function_app.main[0].identity[0].principal_id : azurerm_windows_function_app.main[0].identity[0].principal_id) : null
}

output "function_code_path" {
  description = "Path del package della function"
  value       = data.archive_file.function_code.output_path
}

output "deploy_command" {
  description = "Comando per deployare la function"
  value       = "az functionapp deployment source config-zip -g ${azurerm_resource_group.main.name} -n ${var.function_app_name} --src ${data.archive_file.function_code.output_path} --build-remote true"
}

output "test_curl_command" {
  description = "Comando curl per testare la function"
  value       = "curl 'https://${var.os_type == "Linux" ? azurerm_linux_function_app.main[0].default_hostname : azurerm_windows_function_app.main[0].default_hostname}/api/list-blobs?path=test/' -H 'x-functions-key: <YOUR_FUNCTION_KEY>'"
}

output "apim_gateway_url" {
  value = azurerm_api_management.main.gateway_url
}

output "api_base_url" {
  value = "${azurerm_api_management.main.gateway_url}/api"
}

output "get_files_url" {
  value = "${azurerm_api_management.main.gateway_url}/api/files"
}

output "post_calculate_url" {
  value = "${azurerm_api_management.main.gateway_url}/api/calculate"
}

output "function_app_name" {
  value = azurerm_linux_function_app.main.name
}

output "storage_account_name" {
  value = azurerm_storage_account.files.name
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "apim_name" {
  value = azurerm_api_management.main.name
}

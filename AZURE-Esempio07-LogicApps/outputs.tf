output "logic_app_id" {
  value = azurerm_logic_app_workflow.main.id
}

output "function_app_name" {
  value = azurerm_linux_function_app.main.name
}

output "source_storage_name" {
  value = azurerm_storage_account.source.name
}

output "destination_storage_name" {
  value = azurerm_storage_account.destination.name
}

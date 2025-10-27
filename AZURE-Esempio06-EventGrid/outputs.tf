output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "source_storage_account_name" {
  value = azurerm_storage_account.source.name
}

output "source_container_name" {
  value = azurerm_storage_container.source.name
}

output "function_app_name" {
  value = azurerm_linux_function_app.main.name
}

output "eventgrid_topic_id" {
  value = azurerm_eventgrid_system_topic.storage.id
}

output "eventgrid_subscription_id" {
  value = azurerm_eventgrid_event_subscription.blob_created.id
}

output "test_upload_command" {
  value = "az storage blob upload -f test.txt -c ${azurerm_storage_container.source.name} -n test.txt --account-name ${azurerm_storage_account.source.name}"
}

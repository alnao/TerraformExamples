output "resource_group_name" {
  description = "Nome del Resource Group"
  value       = azurerm_resource_group.main.name
}

output "cosmosdb_account_id" {
  description = "ID dell'account CosmosDB"
  value       = azurerm_cosmosdb_account.main.id
}

output "cosmosdb_account_name" {
  description = "Nome dell'account CosmosDB"
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmosdb_endpoint" {
  description = "Endpoint CosmosDB"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmosdb_connection_strings" {
  description = "Connection strings MongoDB"
  value       = azurerm_cosmosdb_account.main.connection_strings
  sensitive   = true
}

output "cosmosdb_primary_key" {
  description = "Primary master key"
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "cosmosdb_secondary_key" {
  description = "Secondary master key"
  value       = azurerm_cosmosdb_account.main.secondary_key
  sensitive   = true
}

output "database_name" {
  description = "Nome del database MongoDB"
  value       = azurerm_cosmosdb_mongo_database.main.name
}

output "collection_names" {
  description = "Nomi delle collections create"
  value       = keys(var.collections)
}

output "read_endpoints" {
  description = "Read endpoints per region"
  value       = azurerm_cosmosdb_account.main.read_endpoints
}

output "write_endpoints" {
  description = "Write endpoints per region"
  value       = azurerm_cosmosdb_account.main.write_endpoints
}

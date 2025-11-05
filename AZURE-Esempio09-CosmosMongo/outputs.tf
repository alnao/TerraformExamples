output "resource_group_name" {
  description = "Nome del Resource Group"
  value       = azurerm_resource_group.main.name
}

output "cosmosdb_mongo_cluster_name" {
  description = "Nome del Cosmos DB Mongo Cluster"
  value       = azurerm_mongo_cluster.cosmosdb_vcore.name
}

output "cosmosdb_mongo_cluster_id" {
  description = "ID del Cosmos DB Mongo Cluster"
  value       = azurerm_mongo_cluster.cosmosdb_vcore.id
}

output "cosmosdb_connection_strings" {
  description = "Connection strings del Mongo Cluster"
  value       = azurerm_mongo_cluster.cosmosdb_vcore.connection_strings
  sensitive   = true
}

output "private_endpoint_id" {
  description = "ID del Private Endpoint (se abilitato)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.cosmosdb_vcore[0].id : null
}

output "private_endpoint_ip" {
  description = "Indirizzo IP privato del Private Endpoint (se abilitato)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.cosmosdb_vcore[0].private_service_connection[0].private_ip_address : null
}

output "key_vault_id" {
  description = "ID del Key Vault (se abilitato)"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].id : null
}

output "key_vault_name" {
  description = "Nome del Key Vault (se abilitato)"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].name : null
}

output "key_vault_uri" {
  description = "URI del Key Vault (se abilitato)"
  value       = var.enable_key_vault ? azurerm_key_vault.main[0].vault_uri : null
}

output "key_vault_secret_names" {
  description = "Nomi dei secrets creati nel Key Vault"
  value = var.enable_key_vault ? [
    azurerm_key_vault_secret.mongodb_connection_string[0].name,
    azurerm_key_vault_secret.mongodb_username[0].name,
    azurerm_key_vault_secret.mongodb_password[0].name
  ] : []
}

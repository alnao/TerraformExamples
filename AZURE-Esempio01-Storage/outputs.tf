# Output del Resource Group
output "resource_group_name" {
  description = "Nome del Resource Group creato"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID del Resource Group creato"
  value       = azurerm_resource_group.main.id
}

output "location" {
  description = "Regione dove sono state create le risorse"
  value       = azurerm_resource_group.main.location
}

# Output dello Storage Account
output "storage_account_name" {
  description = "Nome dello Storage Account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "ID dello Storage Account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_primary_location" {
  description = "Località primaria dello Storage Account"
  value       = azurerm_storage_account.main.primary_location
}

output "storage_account_secondary_location" {
  description = "Località secondaria dello Storage Account (se applicabile)"
  value       = azurerm_storage_account.main.secondary_location
}

# Output delle chiavi di accesso
output "storage_account_primary_access_key" {
  description = "Chiave di accesso primaria dello Storage Account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "storage_account_secondary_access_key" {
  description = "Chiave di accesso secondaria dello Storage Account"
  value       = azurerm_storage_account.main.secondary_access_key
  sensitive   = true
}

output "storage_account_primary_connection_string" {
  description = "Connection string primaria dello Storage Account"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "storage_account_secondary_connection_string" {
  description = "Connection string secondaria dello Storage Account"
  value       = azurerm_storage_account.main.secondary_connection_string
  sensitive   = true
}

# Output degli endpoint
output "storage_account_primary_blob_endpoint" {
  description = "Endpoint primario per i blob"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "storage_account_secondary_blob_endpoint" {
  description = "Endpoint secondario per i blob"
  value       = azurerm_storage_account.main.secondary_blob_endpoint
}

output "storage_account_primary_web_endpoint" {
  description = "Endpoint primario per hosting web statico"
  value       = azurerm_storage_account.main.primary_web_endpoint
}

output "storage_account_primary_dfs_endpoint" {
  description = "Endpoint primario per Data Lake Storage"
  value       = azurerm_storage_account.main.primary_dfs_endpoint
}

# Output dei container
output "container_names" {
  description = "Nomi dei container creati"
  value       = azurerm_storage_container.main[*].name
}

output "container_urls" {
  description = "URL dei container creati"
  value = [
    for container in azurerm_storage_container.main :
    "${azurerm_storage_account.main.primary_blob_endpoint}${container.name}"
  ]
}

# Output delle informazioni di configurazione
output "account_tier" {
  description = "Tier dell'account storage"
  value       = azurerm_storage_account.main.account_tier
}

output "replication_type" {
  description = "Tipo di replica configurato"
  value       = azurerm_storage_account.main.account_replication_type
}

output "account_kind" {
  description = "Tipo di account storage"
  value       = azurerm_storage_account.main.account_kind
}

# Output delle configurazioni di sicurezza
output "public_network_access_enabled" {
  description = "Stato dell'accesso da rete pubblica"
  value       = azurerm_storage_account.main.public_network_access_enabled
}

output "min_tls_version" {
  description = "Versione minima di TLS configurata"
  value       = azurerm_storage_account.main.min_tls_version
}

# Output utili per l'integrazione con altre risorse
output "storage_account_resource_info" {
  description = "Informazioni complete dello Storage Account per riferimenti esterni"
  value = {
    name                = azurerm_storage_account.main.name
    id                  = azurerm_storage_account.main.id
    resource_group_name = azurerm_storage_account.main.resource_group_name
    primary_endpoint    = azurerm_storage_account.main.primary_blob_endpoint
    location            = azurerm_storage_account.main.location
  }
}

# ── CosmosDB Mongo Cluster (≈ DynamoDB table outputs) ────────────────────────────

output "resource_group_name" {
  description = "Nome del Resource Group"
  value       = azurerm_resource_group.main.name
}

output "cosmosdb_mongo_cluster_name" {
  description = "Nome del Cosmos DB Mongo Cluster (≈ table_name)"
  value       = azurerm_mongo_cluster.main.name
}

output "cosmosdb_mongo_cluster_id" {
  description = "ID del Cosmos DB Mongo Cluster (≈ table_arn)"
  value       = azurerm_mongo_cluster.main.id
}

output "cosmosdb_connection_strings" {
  description = "Connection strings del Mongo Cluster (≈ endpoint/stream_arn)"
  value       = azurerm_mongo_cluster.main.connection_strings
  sensitive   = true
}

output "mongodb_version" {
  description = "Versione MongoDB del cluster"
  value       = azurerm_mongo_cluster.main.version
}

# ── Firewall ──────────────────────────────────────────────────────────────────────

output "firewall_rule_info" {
  description = "Info firewall rule (se abilitata)"
  value       = var.enable_firewall_rule ? "AllowMyIP — IP: ${var.my_ip_address}" : null
}

# ── Private Endpoint ──────────────────────────────────────────────────────────────

output "private_endpoint_id" {
  description = "ID del Private Endpoint (se abilitato)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.main[0].id : null
}

output "private_endpoint_ip" {
  description = "IP privato del Private Endpoint (se abilitato)"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.main[0].private_service_connection[0].private_ip_address : null
}

# ── Key Vault ─────────────────────────────────────────────────────────────────────

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

# ── Blob Function Integration (≈ S3 + Lambda outputs) ────────────────────────────

output "storage_account_name" {
  description = "Nome dello Storage Account (≈ s3_bucket_name)"
  value       = var.enable_blob_function_integration ? azurerm_storage_account.function[0].name : null
}

output "storage_account_id" {
  description = "ID dello Storage Account (≈ s3_bucket_arn)"
  value       = var.enable_blob_function_integration ? azurerm_storage_account.function[0].id : null
}

output "function_app_name" {
  description = "Nome della Function App (≈ lambda_function_name)"
  value       = var.enable_blob_function_integration ? azurerm_linux_function_app.main[0].name : null
}

output "function_app_id" {
  description = "ID della Function App (≈ lambda_function_arn)"
  value       = var.enable_blob_function_integration ? azurerm_linux_function_app.main[0].id : null
}

output "function_app_default_hostname" {
  description = "Hostname della Function App"
  value       = var.enable_blob_function_integration ? azurerm_linux_function_app.main[0].default_hostname : null
}

output "function_app_identity_principal_id" {
  description = "Principal ID della Managed Identity della Function App (≈ IAM role ARN)"
  value       = var.enable_blob_function_integration ? azurerm_linux_function_app.main[0].identity[0].principal_id : null
}

# ── Application Insights (≈ CloudWatch) ──────────────────────────────────────────

output "application_insights_connection_string" {
  description = "Connection string di Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.main[0].connection_string : null
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID del Log Analytics Workspace"
  value       = var.enable_application_insights ? azurerm_log_analytics_workspace.main[0].id : null
}

# ── Event Grid (≈ EventBridge/DynamoDB Streams outputs) ──────────────────────────

output "eventgrid_system_topic_name" {
  description = "Nome dell'Event Grid System Topic (≈ eventbridge_rule_name)"
  value       = var.enable_blob_function_integration && var.enable_event_grid ? azurerm_eventgrid_system_topic.blob_events[0].name : null
}

# ── Utility commands ──────────────────────────────────────────────────────────────

output "test_upload_command" {
  description = "Comando per testare upload blob → trigger Function (≈ test_upload_command AWS)"
  value       = var.enable_blob_function_integration ? "az storage blob upload --account-name ${var.storage_account_name} --container-name uploads --name test.txt --data 'test content'" : null
}

output "query_cosmosdb_command" {
  description = "Comando per eseguire test.py (≈ query_dynamodb_command AWS)"
  value       = "python3 test.py --find --database ${var.mongodb_database_name} --collection ${var.mongodb_blob_collection_name}"
}

# ===================================================================================
# Compute: Storage Account + Azure Function App con Blob Trigger
# Equivalente Azure di compute.tf AWS-Esempio09 (S3 + Lambda + EventBridge)
# ===================================================================================
# AWS → Azure mapping:
#   aws_s3_bucket                → azurerm_storage_account + azurerm_storage_container
#   aws_lambda_function          → azurerm_linux_function_app
#   aws_cloudwatch_event_rule    → azurerm_eventgrid_system_topic (monitoring)
#   aws_cloudwatch_log_group     → azurerm_application_insights + azurerm_log_analytics_workspace
#   aws_iam_role                 → System Managed Identity sulla function app

# Storage Account per Function App e Blob Trigger (equivalente a aws_s3_bucket)
resource "azurerm_storage_account" "function" {
  count                    = var.enable_blob_function_integration ? 1 : 0
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

# Container "uploads" — equivalente al bucket S3 trigger di AWS
resource "azurerm_storage_container" "uploads" {
  count                 = var.enable_blob_function_integration ? 1 : 0
  name                  = "uploads"
  storage_account_id    = azurerm_storage_account.function[0].id
  container_access_type = "private"
}

# Container "delete-tracking" per tracciamento eliminazioni (opzionale, come enable_delete_tracking su AWS)
resource "azurerm_storage_container" "deleted" {
  count                 = var.enable_blob_function_integration && var.enable_delete_tracking ? 1 : 0
  name                  = "deleted-tracking"
  storage_account_id    = azurerm_storage_account.function[0].id
  container_access_type = "private"
}

# Log Analytics Workspace (equivalente a CloudWatch Log Group di AWS)
resource "azurerm_log_analytics_workspace" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "${var.cosmosdb_account_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

# Application Insights (equivalente a CloudWatch Metrics/Dashboard di AWS)
resource "azurerm_application_insights" "main" {
  count               = var.enable_application_insights ? 1 : 0
  name                = "${var.cosmosdb_account_name}-appins"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main[0].id
  application_type    = "other"
  tags                = local.tags
}

# App Service Plan Consumption (serverless, equivalente al runtime Lambda di AWS)
resource "azurerm_service_plan" "function" {
  count               = var.enable_blob_function_integration ? 1 : 0
  name                = "${var.function_app_name}-plan"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan, serverless
  tags                = local.tags
}

# Package del codice della Function App (equivalente a archive_file di AWS Lambda)
data "archive_file" "function_zip" {
  count       = var.enable_blob_function_integration ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/function_app.zip"
  source_dir  = "${path.module}/function_app"
}

# Azure Linux Function App (equivalente a aws_lambda_function)
resource "azurerm_linux_function_app" "main" {
  count               = var.enable_blob_function_integration ? 1 : 0
  name                = var.function_app_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.function[0].id

  storage_account_name       = azurerm_storage_account.function[0].name
  storage_account_access_key = azurerm_storage_account.function[0].primary_access_key

  # Deploy del codice zippato (equivalente a filename in aws_lambda_function)
  zip_deploy_file = data.archive_file.function_zip[0].output_path

  # System Managed Identity (equivalente all'IAM Role di Lambda su AWS)
  identity {
    type = "SystemAssigned"
  }

  app_settings = merge(
    {
      # Connection string CosmosDB per la function
      "COSMOSDB_CONNECTION_STRING" = length(azurerm_mongo_cluster.main.connection_strings) > 0 ? azurerm_mongo_cluster.main.connection_strings[0] : ""
      "COSMOSDB_DATABASE"          = var.mongodb_database_name
      "COSMOSDB_COLLECTION"        = var.mongodb_blob_collection_name
      "BLOB_CONTAINER_NAME"        = "uploads"
      # Runtime Python (equivalente a runtime = "python3.11" in aws_lambda_function)
      "FUNCTIONS_WORKER_RUNTIME" = "python"
      # Storage per il runtime della function (AzureWebJobsStorage = trigger interno)
      "AzureWebJobsStorage"      = azurerm_storage_account.function[0].primary_connection_string
      "WEBSITE_RUN_FROM_PACKAGE" = "1"
    },
    var.enable_application_insights ? {
      "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main[0].connection_string
    } : {}
  )

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  tags       = local.tags
  depends_on = [azurerm_mongo_cluster.main]
}

# Event Grid System Topic per Blob Storage (equivalente a DynamoDB Streams/EventBridge su AWS)
# Permette di monitorare eventi di upload/delete sul container "uploads"
resource "azurerm_eventgrid_system_topic" "blob_events" {
  count                  = var.enable_blob_function_integration && var.enable_event_grid ? 1 : 0
  name                   = "${var.cosmosdb_account_name}-blob-topic"
  location               = azurerm_resource_group.main.location
  resource_group_name    = azurerm_resource_group.main.name
  source_arm_resource_id = azurerm_storage_account.function[0].id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  tags                   = local.tags
}

# Azure Monitor Action Group (equivalente a SNS Topic per gli alarm actions di AWS)
resource "azurerm_monitor_action_group" "main" {
  count               = var.enable_monitor_alerts ? 1 : 0
  name                = "${var.cosmosdb_account_name}-alerts"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "es09alert"
  tags                = local.tags
}

# Monitor Metric Alert per richieste CosmosDB (equivalente a aws_cloudwatch_metric_alarm)
# Nota: metriche disponibili per azurerm_mongo_cluster potrebbero variare per versione provider
resource "azurerm_monitor_metric_alert" "cosmosdb_requests" {
  count               = var.enable_monitor_alerts ? 1 : 0
  name                = "${var.cosmosdb_account_name}-mongo-requests"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_mongo_cluster.main.id]
  description         = "Alert when MongoDB requests exceed threshold"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.DocumentDB/mongoClusters"
    metric_name      = "MongoRequestsCount"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.monitor_alert_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.main[0].id
  }

  tags = local.tags
}

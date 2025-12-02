terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Storage Account per Function App
resource "azurerm_storage_account" "function" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_replication_type
  min_tls_version          = "TLS1_2"

  tags = var.tags
}

# Storage Container per Function Code
resource "azurerm_storage_container" "function_releases" {
  name                  = "function-releases"
  storage_account_name  = azurerm_storage_account.function.name
  container_access_type = "private"
}

# Storage Account per testing
resource "azurerm_storage_account" "test" {
  name                     = var.test_storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = var.tags
}

# Container per testing
resource "azurerm_storage_container" "test" {
  name                  = var.test_container_name
  storage_account_name  = azurerm_storage_account.test.name
  container_access_type = "private"
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.function_app_name}-insights"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "other"
  retention_in_days   = var.appinsights_retention_days

  tags = var.tags
}

# Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.function_app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = var.os_type
  sku_name            = var.sku_name

  tags = var.tags
}

# Linux Function App
resource "azurerm_linux_function_app" "main" {
  count                      = var.os_type == "Linux" ? 1 : 0
  name                       = var.function_app_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  site_config {
    application_stack {
      python_version = var.python_version
    }

    cors {
      allowed_origins     = var.cors_allowed_origins
      support_credentials = var.cors_support_credentials
    }

    # Always on (solo per piani non consumption)
    always_on = var.sku_name != "Y1" ? var.always_on : false

    # App service logs
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    application_insights_key               = azurerm_application_insights.main.instrumentation_key

    #zip_deploy_file = data.archive_file.function_code.output_path
    #depends_on = [
    #  data.archive_file.function_code
    #]
  }

  app_settings = merge(
    {
      FUNCTIONS_WORKER_RUNTIME            = "python"
      FUNCTIONS_EXTENSION_VERSION         = "~4"
      AzureWebJobsFeatureFlags            = "EnableWorkerIndexing"
      PYTHON_ISOLATE_WORKER_DEPENDENCIES  = "1"
      SCM_DO_BUILD_DURING_DEPLOYMENT      = "true"
      ENABLE_ORYX_BUILD                   = "true"
      TEST_STORAGE_ACCOUNT_NAME           = azurerm_storage_account.test.name
      TEST_STORAGE_ACCOUNT_KEY            = azurerm_storage_account.test.primary_access_key
      TEST_STORAGE_CONNECTION_STRING      = azurerm_storage_account.test.primary_connection_string
      TEST_CONTAINER_NAME                 = azurerm_storage_container.test.name
    },
    var.app_settings
  )

  identity {
    type = var.enable_managed_identity ? "SystemAssigned" : "None"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# Windows Function App
resource "azurerm_windows_function_app" "main" {
  count                      = var.os_type == "Windows" ? 1 : 0
  name                       = var.function_app_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  site_config {
    cors {
      allowed_origins     = var.cors_allowed_origins
      support_credentials = var.cors_support_credentials
    }

    always_on = var.sku_name != "Y1" ? var.always_on : false

    application_insights_connection_string = azurerm_application_insights.main.connection_string
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
  }

  app_settings = merge(
    {
      FUNCTIONS_WORKER_RUNTIME            = "python"
      FUNCTIONS_EXTENSION_VERSION         = "~4"
      AzureWebJobsFeatureFlags            = "EnableWorkerIndexing"
      PYTHON_ISOLATE_WORKER_DEPENDENCIES  = "1"
      SCM_DO_BUILD_DURING_DEPLOYMENT      = "true"
      ENABLE_ORYX_BUILD                   = "true"
      TEST_STORAGE_ACCOUNT_NAME           = azurerm_storage_account.test.name
      TEST_STORAGE_ACCOUNT_KEY            = azurerm_storage_account.test.primary_access_key
      TEST_STORAGE_CONNECTION_STRING      = azurerm_storage_account.test.primary_connection_string
      TEST_CONTAINER_NAME                 = azurerm_storage_container.test.name
    },
    var.app_settings
  )

  identity {
    type = var.enable_managed_identity ? "SystemAssigned" : "None"
  }

  tags = var.tags
}

# Role Assignment per Managed Identity (accesso Storage)
resource "azurerm_role_assignment" "storage_blob_data_reader" {
  count                = var.enable_managed_identity ? 1 : 0
  scope                = azurerm_storage_account.test.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.os_type == "Linux" ? azurerm_linux_function_app.main[0].identity[0].principal_id : azurerm_windows_function_app.main[0].identity[0].principal_id
}

# Function Code Archive
data "archive_file" "function_code" {
  type        = "zip"
  output_path = "${path.module}/function_app.zip"
  source_dir  = "${path.module}/code"
  #source {
  #  content  = file("${path.module}/__init__.py")
  #  filename = "__init__.py"
  #}
  #source {
  #  content  = file("${path.module}/function.json")
  #  filename = "function.json"
  #}
  #source {
  #  content  = file("${path.module}/host.json")
  #  filename = "host.json"
  #}
  #source {
  #  content  = file("${path.module}/requirements.txt")
  #  filename = "requirements.txt"
  #}
}

# Deploy function code (usando null_resource per demo)
# In produzione, usare Azure DevOps, GitHub Actions, o zip deploy
resource "null_resource" "deploy_function" {
  count = var.auto_deploy_function ? 1 : 0

  triggers = {
    code_hash = data.archive_file.function_code.output_base64sha256
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Function code ready at: ${data.archive_file.function_code.output_path}"
      echo "Deploy with: az functionapp deployment source config-zip -g ${azurerm_resource_group.main.name} -n ${var.function_app_name} --src ${data.archive_file.function_code.output_path} --build-remote true"
    EOT
  }

  depends_on = [
    azurerm_linux_function_app.main,
    azurerm_windows_function_app.main
  ]
}

# Metric Alert per errori
resource "azurerm_monitor_metric_alert" "function_errors" {
  count               = var.enable_metric_alerts ? 1 : 0
  name                = "${var.function_app_name}-errors"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [var.os_type == "Linux" ? azurerm_linux_function_app.main[0].id : azurerm_windows_function_app.main[0].id]
  description         = "Alert when function has errors"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.error_alert_threshold
  }

  action {
    action_group_id = var.action_group_id
  }
}

# Metric Alert per response time
resource "azurerm_monitor_metric_alert" "function_response_time" {
  count               = var.enable_metric_alerts && var.response_time_alert_threshold > 0 ? 1 : 0
  name                = "${var.function_app_name}-response-time"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [var.os_type == "Linux" ? azurerm_linux_function_app.main[0].id : azurerm_windows_function_app.main[0].id]
  description         = "Alert when function response time is high"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "HttpResponseTime"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.response_time_alert_threshold
  }

  action {
    action_group_id = var.action_group_id
  }
}

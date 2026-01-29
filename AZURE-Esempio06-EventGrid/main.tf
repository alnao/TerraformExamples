terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
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

# Package Function App code in a zip and upload to the function storage account
data "archive_file" "function_package" {
  type        = "zip"
  source_dir  = "${path.module}/function_code"
  output_path = "${path.module}/function_code.zip"
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Storage Account sorgente
resource "azurerm_storage_account" "source" {
  name                     = var.source_storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "source" {
  name                  = var.source_container_name
  storage_account_name  = azurerm_storage_account.source.name
  container_access_type = "private"
}

# Storage Account per Function App
resource "azurerm_storage_account" "function" {
  name                     = var.function_storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "function_package" {
  name                  = "function-code"
  storage_account_name  = azurerm_storage_account.function.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "function_package" {
  name                   = "${data.archive_file.function_package.output_md5}.zip"
  storage_account_name   = azurerm_storage_account.function.name
  storage_container_name = azurerm_storage_container.function_package.name
  type                   = "Block"
  source                 = data.archive_file.function_package.output_path
  content_md5            = data.archive_file.function_package.output_md5
}


data "azurerm_storage_account_sas" "function_package" {
  connection_string = azurerm_storage_account.function.primary_connection_string

  https_only = true
  start      = timeadd(timestamp(), "-5m")
  expiry     = timeadd(timestamp(), "8760h") # 1 year

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  resource_types {
    service   = false
    container = true
    object    = true
  }

  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.function_app_name}-insights"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "other"
  retention_in_days   = var.appinsights_retention_days
  tags                = var.tags

  lifecycle {
    # Preserve any existing workspace association; Azure does not allow removing it once set.
    ignore_changes = [workspace_id]
  }
}

# Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.function_app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.sku_name
  tags                = var.tags
}

# Linux Function App
resource "azurerm_linux_function_app" "main" {
  name                       = var.function_app_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key
  zip_deploy_file            = data.archive_file.function_package.output_path

  site_config {
    application_stack {
      python_version = var.python_version
    }
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    application_insights_key               = azurerm_application_insights.main.instrumentation_key
  }

  app_settings = merge(
    {
      FUNCTIONS_WORKER_RUNTIME       = "python"
      FUNCTIONS_EXTENSION_VERSION    = "~4"
      AzureWebJobsStorage            = azurerm_storage_account.function.primary_connection_string
      SOURCE_STORAGE_CONNECTION      = azurerm_storage_account.source.primary_connection_string
      SOURCE_STORAGE_ACCOUNT_NAME    = azurerm_storage_account.source.name
      SOURCE_CONTAINER_NAME          = azurerm_storage_container.source.name
    },
    var.app_settings
  )


  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Wait for Function App to be ready and triggers synced
resource "time_sleep" "wait_for_function" {
  create_duration = "120s"
  triggers = {
    # Run when the function app ID changes (e.g. app settings update)
    function_app_id = azurerm_linux_function_app.main.id
    # Run when the package changes
    package_md5    = data.archive_file.function_package.output_md5
  }
}

# Event Grid System Topic per Storage Account
resource "azurerm_eventgrid_system_topic" "storage" {
  name                   = "${var.source_storage_account_name}-topic"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  source_arm_resource_id = azurerm_storage_account.source.id
  topic_type             = "Microsoft.Storage.StorageAccounts"
  tags                   = var.tags
}

# Event Grid Subscription per Blob Created
resource "azurerm_eventgrid_event_subscription" "blob_created" {
  name  = "${var.function_app_name}-blob-created"
  scope = azurerm_storage_account.source.id

  azure_function_endpoint {
    function_id                       = "${azurerm_linux_function_app.main.id}/functions/${var.function_name}"
    max_events_per_batch              = var.max_events_per_batch
    preferred_batch_size_in_kilobytes = var.preferred_batch_size_in_kilobytes
  }

  depends_on = [time_sleep.wait_for_function]

  included_event_types = var.included_event_types

  dynamic "subject_filter" {
    for_each = var.subject_begins_with != "" || var.subject_ends_with != "" ? [1] : []
    content {
      subject_begins_with = var.subject_begins_with
      subject_ends_with   = var.subject_ends_with
      case_sensitive      = var.case_sensitive
    }
  }

  dynamic "advanced_filter" {
    for_each = var.enable_advanced_filter ? [1] : []
    content {
      dynamic "string_contains" {
        for_each = var.advanced_filter_string_contains
        content {
          key    = string_contains.value.key
          values = string_contains.value.values
        }
      }
    }
  }

  retry_policy {
    max_delivery_attempts = var.max_delivery_attempts
    event_time_to_live    = var.event_time_to_live
  }

  dynamic "storage_blob_dead_letter_destination" {
    for_each = var.enable_dead_letter ? [1] : []
    content {
      storage_account_id          = azurerm_storage_account.function.id
      storage_blob_container_name = var.dead_letter_container_name
    }
  }

  labels = var.subscription_labels
}

# Dead Letter Container (opzionale)
resource "azurerm_storage_container" "dead_letter" {
  count                 = var.enable_dead_letter ? 1 : 0
  name                  = var.dead_letter_container_name
  storage_account_name  = azurerm_storage_account.function.name
  container_access_type = "private"
}

# Role Assignment per Managed Identity
resource "azurerm_role_assignment" "storage_blob_data_reader" {
  scope                = azurerm_storage_account.source.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Metric Alert per errori Function
resource "azurerm_monitor_metric_alert" "function_errors" {
  count               = var.enable_metric_alerts ? 1 : 0
  name                = "${var.function_app_name}-errors"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_function_app.main.id]
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

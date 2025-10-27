terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Storage Accounts
resource "azurerm_storage_account" "source" {
  name                     = var.source_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_container" "source" {
  name                  = "source"
  storage_account_name  = azurerm_storage_account.source.name
}

resource "azurerm_storage_account" "destination" {
  name                     = var.destination_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_container" "destination" {
  name                  = "destination"
  storage_account_name  = azurerm_storage_account.destination.name
}

# Storage per Function
resource "azurerm_storage_account" "function" {
  name                     = var.function_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.logic_app_name}-insights"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "other"
  tags                = var.tags
}

# Service Plan per Function
resource "azurerm_service_plan" "main" {
  name                = "${var.function_app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

# Function App per logging
resource "azurerm_linux_function_app" "main" {
  name                       = var.function_app_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  service_plan_id            = azurerm_service_plan.main.id
  storage_account_name       = azurerm_storage_account.function.name
  storage_account_access_key = azurerm_storage_account.function.primary_access_key

  site_config {
    application_stack {
      python_version = "3.11"
    }
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Logic App (Consumption)
resource "azurerm_logic_app_workflow" "main" {
  name                = var.logic_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# API Connections per Logic App
resource "azurerm_api_connection" "azureblob" {
  name                = "azureblob-connection"
  resource_group_name = azurerm_resource_group.main.name
  managed_api_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/azureblob"
  display_name        = "Azure Blob Connection"
  
  parameter_values = {
    accountName = azurerm_storage_account.source.name
    accessKey   = azurerm_storage_account.source.primary_access_key
  }
}

data "azurerm_client_config" "current" {}

# Logic App Trigger e Actions (definito dopo il deploy)
resource "azurerm_logic_app_trigger_custom" "blob_created" {
  name         = "When_a_blob_is_added"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type       = "ApiConnection"
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['azureblob']['connectionId']"
        }
      }
      method = "get"
      path   = "/datasets/default/triggers/batch/onupdatedfile"
      queries = {
        folderId       = base64encode(azurerm_storage_container.source.name)
        maxFileCount   = 10
        checkBothCreatedAndModifiedDateTime = false
      }
    }
    recurrence = {
      frequency = "Minute"
      interval  = 1
    }
    splitOn = "@triggerBody()"
  })
}

# Role Assignments
resource "azurerm_role_assignment" "logicapp_source_reader" {
  scope                = azurerm_storage_account.source.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_logic_app_workflow.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "logicapp_dest_contributor" {
  scope                = azurerm_storage_account.destination.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_logic_app_workflow.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_contributor" {
  scope                = azurerm_storage_account.source.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

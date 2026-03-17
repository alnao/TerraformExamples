terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50.0"
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
  name               = "source"
  storage_account_id = azurerm_storage_account.source.id
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
  name               = "destination"
  storage_account_id = azurerm_storage_account.destination.id
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

# Crea archivio ZIP della funzione dalla sottocartella function/
data "archive_file" "function_code" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
}

# Storage container per il deploy della funzione
resource "azurerm_storage_container" "function_deploy" {
  name               = "function-releases"
  storage_account_id = azurerm_storage_account.function.id
}

# Upload del codice della funzione
resource "azurerm_storage_blob" "function_code" {
  name                   = "function-${filemd5(data.archive_file.function_code.output_path)}.zip"
  storage_account_name   = azurerm_storage_account.function.name
  storage_container_name = azurerm_storage_container.function_deploy.name
  type                   = "Block"
  source                 = data.archive_file.function_code.output_path
}

# SAS token per il download della funzione
data "azurerm_storage_account_blob_container_sas" "function_sas" {
  connection_string = azurerm_storage_account.function.primary_connection_string
  container_name    = azurerm_storage_container.function_deploy.name
  https_only        = true

  start  = "2024-01-01T00:00:00Z"
  expiry = "2027-12-31T23:59:59Z"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}

# Log Analytics Workspace per Application Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.logic_app_name}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "${var.logic_app_name}-insights"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "other"
  workspace_id        = azurerm_log_analytics_workspace.main.id
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
    FUNCTIONS_WORKER_RUNTIME                   = "python"
    WEBSITE_RUN_FROM_PACKAGE                   = "https://${azurerm_storage_account.function.name}.blob.core.windows.net/${azurerm_storage_container.function_deploy.name}/${azurerm_storage_blob.function_code.name}${data.azurerm_storage_account_blob_container_sas.function_sas.sas}"
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.main.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.main.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  depends_on = [
    azurerm_storage_blob.function_code
  ]
}

# Logic App (Consumption)
resource "azurerm_logic_app_workflow" "main" {
  name                = var.logic_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }

  workflow_parameters = {
    "$connections" = jsonencode({
      type         = "Object"
      defaultValue = {}
    })
  }

  parameters = {
    "$connections" = jsonencode({
      azureblob_source = {
        connectionId   = azurerm_api_connection.azureblob_source.id
        connectionName = azurerm_api_connection.azureblob_source.name
        id             = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/azureblob"
      }
      azureblob_dest = {
        connectionId   = azurerm_api_connection.azureblob_dest.id
        connectionName = azurerm_api_connection.azureblob_dest.name
        id             = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/azureblob"
      }
    })
  }

  tags = var.tags

  depends_on = [
    azurerm_api_connection.azureblob_source,
    azurerm_api_connection.azureblob_dest,
    azurerm_linux_function_app.main
  ]
}

# API Connection per Source Storage
resource "azurerm_api_connection" "azureblob_source" {
  name                = "azureblob-source-connection"
  resource_group_name = azurerm_resource_group.main.name
  managed_api_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/azureblob"
  display_name        = "Azure Blob Source Connection"

  parameter_values = {
    accountName = azurerm_storage_account.source.name
    accessKey   = azurerm_storage_account.source.primary_access_key
  }
}

# API Connection per Destination Storage
resource "azurerm_api_connection" "azureblob_dest" {
  name                = "azureblob-dest-connection"
  resource_group_name = azurerm_resource_group.main.name
  managed_api_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.main.location}/managedApis/azureblob"
  display_name        = "Azure Blob Destination Connection"

  parameter_values = {
    accountName = azurerm_storage_account.destination.name
    accessKey   = azurerm_storage_account.destination.primary_access_key
  }
}

data "azurerm_client_config" "current" {}

# Recupera il default host key della Function App
data "azurerm_function_app_host_keys" "main" {
  name                = azurerm_linux_function_app.main.name
  resource_group_name = azurerm_resource_group.main.name

  depends_on = [azurerm_linux_function_app.main]
}

# Trigger: monitoraggio container source per nuovi blob
resource "azurerm_logic_app_trigger_custom" "blob_trigger" {
  name         = "When_a_blob_is_added_or_modified"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "ApiConnection"
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['azureblob_source']['connectionId']"
        }
      }
      method = "get"
      path   = "/v2/datasets/@{encodeURIComponent(encodeURIComponent('${azurerm_storage_account.source.name}'))}/triggers/batch/onupdatedfile"
      queries = {
        checkBothCreatedAndModifiedDateTime = false
        folderId                            = "L3NvdXJjZQ=="
        maxFileCount                        = 10
      }
    }
    recurrence = {
      frequency = "Minute"
      interval  = 1
    }
    splitOn = "@triggerBody()"
  })
}

# Action 1: Leggi contenuto blob da source
resource "azurerm_logic_app_action_custom" "get_blob_content" {
  name         = "Get_blob_content"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "ApiConnection"
    inputs = {
      host = {
        connection = {
          name = "@parameters('$connections')['azureblob_source']['connectionId']"
        }
      }
      method = "get"
      path   = "/v2/datasets/@{encodeURIComponent(encodeURIComponent('${azurerm_storage_account.source.name}'))}/GetFileContentByPath"
      queries = {
        path            = "@triggerBody()?['Path']"
        inferContentType = true
        queryParametersSingleEncoded = true
      }
    }
    runAfter = {}
  })

  depends_on = [azurerm_logic_app_trigger_custom.blob_trigger]
}

# Action 2: Crea blob in destination
resource "azurerm_logic_app_action_custom" "create_blob_destination" {
  name         = "Create_blob_in_destination"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "ApiConnection"
    inputs = {
      body = "@body('Get_blob_content')"
      headers = {
        ReadFileMetadataFromServer = true
      }
      host = {
        connection = {
          name = "@parameters('$connections')['azureblob_dest']['connectionId']"
        }
      }
      method = "post"
      path   = "/v2/datasets/@{encodeURIComponent(encodeURIComponent('${azurerm_storage_account.destination.name}'))}/files"
      queries = {
        folderPath                   = "/destination"
        name                         = "@triggerBody()?['Name']"
        queryParametersSingleEncoded = true
      }
    }
    runAfter = {
      Get_blob_content = ["Succeeded"]
    }
  })

  depends_on = [azurerm_logic_app_action_custom.get_blob_content]
}

# Action 3: Chiamata HTTP alla Function per logging
resource "azurerm_logic_app_action_custom" "call_logger" {
  name         = "Call_Logger_Function"
  logic_app_id = azurerm_logic_app_workflow.main.id

  body = jsonencode({
    type = "Http"
    inputs = {
      method = "POST"
      uri    = "https://${azurerm_linux_function_app.main.default_hostname}/api/logger?code=${data.azurerm_function_app_host_keys.main.default_function_key}"
      headers = {
        "Content-Type" = "application/json"
      }
      body = {
        blobName             = "@triggerBody()?['Name']"
        sourceContainer      = "source"
        destinationContainer = "destination"
        operationTime        = "@{utcNow()}"
      }
    }
    runAfter = {
      Create_blob_in_destination = ["Succeeded"]
    }
  })

  depends_on = [azurerm_logic_app_action_custom.create_blob_destination]
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

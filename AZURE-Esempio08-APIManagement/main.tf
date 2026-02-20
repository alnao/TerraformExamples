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

# Storage Account per GET API
resource "azurerm_storage_account" "files" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_container" "files" {
  name                  = "files"
  storage_account_name  = azurerm_storage_account.files.name
}

# Storage per Functions
resource "azurerm_storage_account" "function" {
  name                     = var.function_storage_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.apim_name}-logs"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# Application Insights (workspace-based)
resource "azurerm_application_insights" "main" {
  name                = "${var.apim_name}-insights"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "other"
  workspace_id        = azurerm_log_analytics_workspace.main.id
  tags                = var.tags
}

# Service Plan
resource "azurerm_service_plan" "main" {
  name                = "${var.function_app_name}-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

# Function App
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
    FUNCTIONS_WORKER_RUNTIME           = "python"
    FUNCTIONS_EXTENSION_VERSION         = "~4"
    AzureWebJobsFeatureFlags            = "EnableWorkerIndexing"
    SCM_DO_BUILD_DURING_DEPLOYMENT      = "true"
    ENABLE_ORYX_BUILD                   = "true"
    FILES_STORAGE_CONNECTION            = azurerm_storage_account.files.primary_connection_string
    FILES_STORAGE_ACCOUNT_NAME          = azurerm_storage_account.files.name
    FILES_CONTAINER_NAME                = azurerm_storage_container.files.name
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# API Management
resource "azurerm_api_management" "main" {
  name                = var.apim_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.apim_sku

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# API Management Logger
resource "azurerm_api_management_logger" "main" {
  name                = "appinsights-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  application_insights {
    instrumentation_key = azurerm_application_insights.main.instrumentation_key
  }
}

# API Management API
resource "azurerm_api_management_api" "main" {
  name                = "${var.apim_name}-api"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = "Esempio08 API"
  path                = "api"
  protocols           = ["https"]

  subscription_required = var.subscription_required
}

# API Operation 1: GET /files
resource "azurerm_api_management_api_operation" "get_files" {
  operation_id        = "get-files"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Get Files List"
  method              = "GET"
  url_template        = "/files"
  description         = "Lista file da Storage Blob"

  response {
    status_code = 200
    description = "Success"
  }
}

# API Operation 2: POST /calculate
resource "azurerm_api_management_api_operation" "post_calculate" {
  operation_id        = "post-calculate"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Calculate Hypotenuse"
  method              = "POST"
  url_template        = "/calculate"
  description         = "Calcola ipotenusa dati due cateti"

  request {
    description = "Request body con cateto_a e cateto_b"
    
    representation {
      content_type = "application/json"
      example {
        name  = "default"
        value = jsonencode({
          cateto_a = 3
          cateto_b = 4
        })
      }
    }
  }

  response {
    status_code = 200
    description = "Success"
    representation {
      content_type = "application/json"
    }
  }
}

# Backend per Functions
resource "azurerm_api_management_backend" "function" {
  name                = "function-backend"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = "https://${azurerm_linux_function_app.main.default_hostname}/api"

}

# Policy per GET /files
resource "azurerm_api_management_api_operation_policy" "get_files" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  operation_id        = azurerm_api_management_api_operation.get_files.operation_id

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="${azurerm_api_management_backend.function.name}" />
        <rewrite-uri template="/list-blobs" />
        <set-header name="x-functions-key" exists-action="override">
            <value>{{function-key}}</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

# Policy per POST /calculate
resource "azurerm_api_management_api_operation_policy" "post_calculate" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  operation_id        = azurerm_api_management_api_operation.post_calculate.operation_id

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="${azurerm_api_management_backend.function.name}" />
        <rewrite-uri template="/calculate-hypotenuse" />
        <set-header name="x-functions-key" exists-action="override">
            <value>{{function-key}}</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

# Role Assignment
resource "azurerm_role_assignment" "function_storage_reader" {
  scope                = azurerm_storage_account.files.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# Named Value per Function Key (da configurare manualmente dopo il deploy)
resource "azurerm_api_management_named_value" "function_key" {
  name                = "function-key"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "function-key"
  value               = "default-key-placeholder"
  secret              = true

  lifecycle {
    ignore_changes = [value]
  }
}

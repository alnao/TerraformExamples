variable "resource_group_name" {
  description = "Nome del resource group"
  type        = string
  default     = "alnao-terraform-esempio05-functions"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westeurope"
}

# Storage Accounts
variable "storage_account_name" {
  description = "Nome dello storage account per Function App"
  type        = string
  default     = "stfuncapp05"
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage replication type"
  type        = string
  default     = "LRS"
}

variable "test_storage_account_name" {
  description = "Nome dello storage account per testing"
  type        = string
  default     = "sttest05"
}

variable "test_container_name" {
  description = "Nome del container per testing"
  type        = string
  default     = "testdata"
}

# Function App
variable "function_app_name" {
  description = "Nome della Function App"
  type        = string
  default     = "func-blob-list-05"
}

variable "os_type" {
  description = "OS type (Linux o Windows)"
  type        = string
  default     = "Linux"

  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type deve essere Linux o Windows"
  }
}

variable "sku_name" {
  description = "SKU del Service Plan (Y1=Consumption, B1=Basic, P1V2=Premium)"
  type        = string
  default     = "Y1"
}

variable "python_version" {
  description = "Versione Python"
  type        = string
  default     = "3.11"
}

variable "always_on" {
  description = "Always On (non disponibile per Consumption)"
  type        = bool
  default     = false
}

# Application Insights
variable "appinsights_retention_days" {
  description = "Giorni di retention per Application Insights"
  type        = number
  default     = 30
}

# CORS
variable "cors_allowed_origins" {
  description = "Origins ammessi per CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_support_credentials" {
  description = "Support credentials per CORS"
  type        = bool
  default     = false
}

# App Settings
variable "app_settings" {
  description = "App settings aggiuntive"
  type        = map(string)
  default     = {}
}

# Managed Identity
variable "enable_managed_identity" {
  description = "Abilita System Assigned Managed Identity"
  type        = bool
  default     = true
}

# Function Code
variable "function_code_init" {
  description = "Codice Python della function"
  type        = string
  default     = <<-EOF
import logging
import json
import os
import azure.functions as func
from azure.storage.blob import BlobServiceClient
from urllib.parse import unquote

def main(req: func.HttpRequest) -> func.HttpResponse:
    """
    Azure Function che lista i blob in un container.
    Può ricevere il path come query parameter.
    """
    logging.info('Python HTTP trigger function processed a request.')

    try:
        # Ottieni configurazione dall'ambiente
        connection_string = os.environ.get('TEST_STORAGE_CONNECTION_STRING')
        container_name = os.environ.get('TEST_CONTAINER_NAME', 'testdata')
        
        # Ottieni il path dal query parameter
        path = req.params.get('path', '')
        if path:
            path = unquote(path)
            if not path.endswith('/') and path != '':
                path += '/'
        
        logging.info(f'Listing blobs in container: {container_name}, path: {path}')
        
        # Crea blob service client
        blob_service_client = BlobServiceClient.from_connection_string(connection_string)
        container_client = blob_service_client.get_container_client(container_name)
        
        # Lista blob con prefix
        blobs = []
        blob_list = container_client.list_blobs(name_starts_with=path)
        
        for blob in blob_list:
            blobs.append({
                'name': blob.name,
                'size': blob.size,
                'last_modified': blob.last_modified.isoformat() if blob.last_modified else None,
                'content_type': blob.content_settings.content_type if blob.content_settings else None,
                'blob_type': str(blob.blob_type) if blob.blob_type else 'BlockBlob'
            })
        
        # Prepara risposta
        result = {
            'container': container_name,
            'path': path,
            'count': len(blobs),
            'blobs': blobs
        }
        
        return func.HttpResponse(
            body=json.dumps(result, indent=2),
            mimetype='application/json',
            status_code=200
        )
        
    except Exception as e:
        logging.error(f'Error: {str(e)}')
        return func.HttpResponse(
            body=json.dumps({'error': str(e)}),
            mimetype='application/json',
            status_code=500
        )
  EOF
}

variable "function_json" {
  description = "Configurazione function.json"
  type        = string
  default     = <<-EOF
{
  "scriptFile": "__init__.py",
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req",
      "methods": [
        "get",
        "post"
      ],
      "route": "list-blobs"
    },
    {
      "type": "http",
      "direction": "out",
      "name": "$return"
    }
  ]
}
  EOF
}

variable "host_json" {
  description = "Configurazione host.json"
  type        = string
  default     = <<-EOF
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    },
    "logLevel": {
      "default": "Information",
      "Function": "Information"
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
  EOF
}

variable "requirements_txt" {
  description = "Requirements Python"
  type        = string
  default     = <<-EOF
azure-functions
azure-storage-blob>=12.19.0
  EOF
}

variable "auto_deploy_function" {
  description = "Auto deploy della function (solo per demo)"
  type        = bool
  default     = false
}

# Metric Alerts
variable "enable_metric_alerts" {
  description = "Abilita metric alerts"
  type        = bool
  default     = false
}

variable "error_alert_threshold" {
  description = "Threshold per alert errori (HTTP 5xx)"
  type        = number
  default     = 5
}

variable "response_time_alert_threshold" {
  description = "Threshold per alert response time (secondi, 0=disabilitato)"
  type        = number
  default     = 0
}

variable "action_group_id" {
  description = "ID dell'Action Group per gli alert"
  type        = string
  default     = ""
}

# Tags
variable "tags" {
  description = "Tags da applicare alle risorse"
  type        = map(string)
  default = {
    Environment = "Dev"
    Owner       = "alnao"
    Example     = "Esempio05Functions"
    CreatedBy   = "Terraform"
  }
}

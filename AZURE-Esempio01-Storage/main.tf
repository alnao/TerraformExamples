# Configurazione del provider Azure
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Configurazione del provider Azure
provider "azurerm" {
  features {}
}

# Creazione del Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Creazione dello Storage Account
resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = var.account_kind

  # Configurazioni di sicurezza
  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = var.allow_public_access
  public_network_access_enabled   = var.public_network_access

  # Configurazione di accesso blob
  blob_properties {
    versioning_enabled = var.enable_versioning
    change_feed_enabled = var.enable_change_feed
    change_feed_retention_in_days = var.enable_change_feed ? var.change_feed_retention_days : null

    dynamic "delete_retention_policy" {
      for_each = var.enable_soft_delete ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }

    dynamic "container_delete_retention_policy" {
      for_each = var.enable_container_soft_delete ? [1] : []
      content {
        days = var.container_soft_delete_retention_days
      }
    }
  }

  tags = var.tags
}

# Creazione del container blob (equivalente al bucket S3)
resource "azurerm_storage_container" "main" {
  count                 = length(var.containers)
  name                  = var.containers[count.index].name
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = var.containers[count.index].access_type
}

# Configurazione del ciclo di vita (lifecycle management)
resource "azurerm_storage_management_policy" "main" {
  count              = var.enable_lifecycle_policy ? 1 : 0
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "lifecycle-rule"
    enabled = true

    filters {
      prefix_match = var.lifecycle_prefix_match
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = var.lifecycle_cool_after_days
        tier_to_archive_after_days_since_modification_greater_than = var.lifecycle_archive_after_days
        delete_after_days_since_modification_greater_than          = var.lifecycle_delete_after_days
      }
    }
  }
}

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

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# CosmosDB Account con MongoDB API
resource "azurerm_cosmosdb_account" "main" {
  name                = var.cosmosdb_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "MongoDB"

  # Capabilities per MongoDB
  capabilities {
    name = "EnableMongo"
  }

  # Server version MongoDB
  dynamic "capabilities" {
    for_each = var.mongo_server_version == "4.2" ? [1] : []
    content {
      name = "EnableMongoDBv4.2"
    }
  }

  dynamic "capabilities" {
    for_each = var.enable_serverless ? [1] : []
    content {
      name = "EnableServerless"
    }
  }

  # Abilitazione zone redundancy
  dynamic "capabilities" {
    for_each = var.enable_zone_redundancy ? [1] : []
    content {
      name = "EnableZoneRedundancy"
    }
  }

  # Consistency policy
  consistency_policy {
    consistency_level       = var.consistency_level
    max_interval_in_seconds = var.consistency_level == "BoundedStaleness" ? var.max_interval_in_seconds : null
    max_staleness_prefix    = var.consistency_level == "BoundedStaleness" ? var.max_staleness_prefix : null
  }

  # Primary region
  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
    zone_redundant    = var.enable_zone_redundancy
  }

  # Secondary regions
  dynamic "geo_location" {
    for_each = var.secondary_locations
    content {
      location          = geo_location.value.location
      failover_priority = geo_location.value.failover_priority
      zone_redundant    = lookup(geo_location.value, "zone_redundant", false)
    }
  }

  # Backup policy
  backup {
    type                = var.backup_type
    interval_in_minutes = var.backup_type == "Periodic" ? var.backup_interval_in_minutes : null
    retention_in_hours  = var.backup_type == "Periodic" ? var.backup_retention_in_hours : null
    storage_redundancy  = var.backup_type == "Periodic" ? var.backup_storage_redundancy : null
  }

  # Network configuration
  public_network_access_enabled     = var.public_network_access_enabled
  is_virtual_network_filter_enabled = var.enable_virtual_network_filter

  dynamic "virtual_network_rule" {
    for_each = var.virtual_network_rules
    content {
      id                                   = virtual_network_rule.value.subnet_id
      ignore_missing_vnet_service_endpoint = lookup(virtual_network_rule.value, "ignore_missing_vnet_service_endpoint", false)
    }
  }

  # IP Firewall
  ip_range_filter = var.ip_range_filter

  # Analytical storage
  analytical_storage_enabled = var.enable_analytical_storage

  # Free tier
  enable_free_tier = var.enable_free_tier

  # Automatic failover
  enable_automatic_failover = var.enable_automatic_failover

  # Multiple write locations
  enable_multiple_write_locations = var.enable_multiple_write_locations

  tags = var.tags
}

# MongoDB Database
resource "azurerm_cosmosdb_mongo_database" "main" {
  name                = var.database_name
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name

  # Throughput (solo se non serverless)
  throughput = var.enable_serverless ? null : (var.enable_autoscale ? null : var.database_throughput)

  # Autoscale
  dynamic "autoscale_settings" {
    for_each = !var.enable_serverless && var.enable_autoscale ? [1] : []
    content {
      max_throughput = var.autoscale_max_throughput
    }
  }
}

# MongoDB Collections
resource "azurerm_cosmosdb_mongo_collection" "collections" {
  for_each = var.collections

  name                = each.key
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_mongo_database.main.name

  # Shard key
  shard_key = lookup(each.value, "shard_key", null)

  # Throughput (solo se non serverless e non ereditato dal database)
  throughput = var.enable_serverless ? null : (
    lookup(each.value, "enable_autoscale", false) ? null : lookup(each.value, "throughput", null)
  )

  # Autoscale per collection
  dynamic "autoscale_settings" {
    for_each = !var.enable_serverless && lookup(each.value, "enable_autoscale", false) ? [1] : []
    content {
      max_throughput = lookup(each.value, "max_throughput", 4000)
    }
  }

  # Default TTL
  default_ttl_seconds = lookup(each.value, "default_ttl_seconds", -1)

  # Analytical storage TTL
  analytical_storage_ttl = var.enable_analytical_storage ? lookup(each.value, "analytical_storage_ttl", -1) : null

  # Indexes
  dynamic "index" {
    for_each = lookup(each.value, "indexes", [])
    content {
      keys   = index.value.keys
      unique = lookup(index.value, "unique", false)
    }
  }
}

# Private Endpoint (opzionale)
resource "azurerm_private_endpoint" "cosmosdb" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.cosmosdb_account_name}-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.cosmosdb_account_name}-psc"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }

  tags = var.tags
}

# Diagnostic Settings (opzionale)
resource "azurerm_monitor_diagnostic_setting" "cosmosdb" {
  count                      = var.enable_diagnostic_settings ? 1 : 0
  name                       = "${var.cosmosdb_account_name}-diagnostics"
  target_resource_id         = azurerm_cosmosdb_account.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "MongoRequests"
  }

  enabled_log {
    category = "PartitionKeyStatistics"
  }

  enabled_log {
    category = "QueryRuntimeStatistics"
  }

  metric {
    category = "Requests"
    enabled  = true
  }
}

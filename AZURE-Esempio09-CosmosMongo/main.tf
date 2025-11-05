# Configurazione del provider Azure
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id  # Usa la variabile se specificata, altrimenti usa default
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Data source per ottenere l'identity corrente (per i permessi Key Vault)
data "azurerm_client_config" "current" {}

locals {
  tags = {
		"deverloper"  = "AlNao",
		"cost-center" = "Alnao-cost-center"
  }
} 

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_mongo_cluster" "cosmosdb_vcore" {
  name                = var.cosmosdb_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  #offer_type          = "Standard"
  #kind                = "MongoDB"

  administrator_username = var.mongodb_username
  administrator_password = var.mongodb_password
  shard_count            = "1"
  compute_tier           = "Free"
  high_availability_mode = "Disabled"
  storage_size_in_gb     = "32"
  public_network_access  = var.enable_public_network_access
  version                = "5.0"
  create_mode            = "Default"
  preview_features       = ["ChangeStreams"]
  tags                   = local.tags
}

# Creazione del database e della collection MongoDB
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cosmosdb_mongo_database.html
# resource "azurerm_cosmosdb_mongo_database" "db" {
#   name                = var.mongodb_database_name
#   resource_group_name = azurerm_resource_group.main.name
#   account_name     = azurerm_mongo_cluster.cosmosdb_vcore.name
#   throughput          = 400
#   # ERRORE IA 
#   # cosmosdb_mongo_cluster_id    = azurerm_mongo_cluster.cosmosdb_vcore.id
# }
# 
# resource "azurerm_cosmosdb_mongo_collection" "annotazioni" {
#   name                = var.mongodb_collection_name
#   resource_group_name = azurerm_resource_group.main.name
#   cosmosdb_mongo_database_id   = azurerm_cosmosdb_mongo_database.db.id
# 
#   # Indici
#   index {
#     keys   = ["_id"]
#     unique = true
#   }
#   throughput = 400
# }

resource "azurerm_private_endpoint" "cosmosdb_vcore" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "cdc-cosmosdb-endpoint"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.private_endpoint[0].id

  private_service_connection {
    name                           = "cdc-cosmosdb-vcore-psconn"
    private_connection_resource_id = azurerm_mongo_cluster.cosmosdb_vcore.id
    is_manual_connection           = false
    subresource_names = [
      "mongoCluster"
    ]
  }

  private_dns_zone_group {
    name                 = data.azurerm_private_dns_zone.internal[0].name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.internal[0].id]
  }

  tags = local.tags
}

# Azure Key Vault per salvare i secrets
resource "azurerm_key_vault" "main" {
  count                       = var.enable_key_vault ? 1 : 0
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  # Accesso pubblico configurabile
  public_network_access_enabled = var.enable_public_network_access == "Enabled" ? true : false

  # Access policy per l'utente/service principal corrente
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
  }

  tags = local.tags
}




# Secret per la connection string MongoDB
resource "azurerm_key_vault_secret" "mongodb_connection_string" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "cosmosdb-mongodb-connection-string"
  value        = jsonencode(azurerm_mongo_cluster.cosmosdb_vcore.connection_strings)
  key_vault_id = azurerm_key_vault.main[0].id

  depends_on = [
    azurerm_key_vault.main
  ]

  tags = local.tags
}

# Secret per username
resource "azurerm_key_vault_secret" "mongodb_username" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "cosmosdb-mongodb-username"
  value        = var.mongodb_username
  key_vault_id = azurerm_key_vault.main[0].id

  depends_on = [
    azurerm_key_vault.main
  ]

  tags = local.tags
}

# Secret per password
resource "azurerm_key_vault_secret" "mongodb_password" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "cosmosdb-mongodb-password"
  value        = var.mongodb_password
  key_vault_id = azurerm_key_vault.main[0].id

  depends_on = [
    azurerm_key_vault.main
  ]

  tags = local.tags
}
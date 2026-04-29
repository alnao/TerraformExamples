# Configurazione del provider Azure
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.50.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Data source per ottenere l'identity corrente (per i permessi Key Vault)
data "azurerm_client_config" "current" {}

locals {
  tags = {
    "developer"   = "AlNao"
    "cost-center" = "Alnao-cost-center"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# Cosmos DB for MongoDB vCore Cluster (equivalente a aws_dynamodb_table)
resource "azurerm_mongo_cluster" "main" {
  name                = var.cosmosdb_account_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  administrator_username = var.mongodb_username
  administrator_password = var.mongodb_password
  shard_count            = "1"
  compute_tier           = var.compute_tier
  high_availability_mode = var.high_availability_mode
  storage_size_in_gb     = var.storage_size_in_gb
  public_network_access  = var.enable_public_network_access
  version                = var.mongodb_version
  create_mode            = "Default"

  # Change Feed = equivalente a DynamoDB Streams per event-driven architecture
  preview_features = var.enable_change_feed ? ["ChangeStreams"] : []

  tags = local.tags
}

# Firewall rule per consentire l'accesso dal proprio IP (opzionale)
# Nota: azurerm_mongo_cluster_firewall_rule non disponibile in ~> 4.50.0, si usa Azure CLI via local-exec
resource "null_resource" "firewall_rule_my_ip" {
  count = var.enable_firewall_rule ? 1 : 0

  triggers = {
    cluster_name        = azurerm_mongo_cluster.main.name
    resource_group_name = azurerm_resource_group.main.name
    ip_address          = var.my_ip_address
  }

  provisioner "local-exec" {
    command = <<-EOT
      az cosmosdb mongocluster firewall rule create \
        --cluster-name ${azurerm_mongo_cluster.main.name} \
        --resource-group ${azurerm_resource_group.main.name} \
        --rule-name AllowMyIP \
        --start-ip-address ${var.my_ip_address} \
        --end-ip-address ${var.my_ip_address}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      az cosmosdb mongocluster firewall rule delete \
        --cluster-name ${self.triggers.cluster_name} \
        --resource-group ${self.triggers.resource_group_name} \
        --rule-name AllowMyIP \
        --yes
    EOT
  }

  depends_on = [azurerm_mongo_cluster.main]
}

# Private Endpoint (opzionale, equivalente alla configurazione VPC endpoint di DynamoDB)
resource "azurerm_private_endpoint" "main" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.cosmosdb_account_name}-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.private_endpoint[0].id

  private_service_connection {
    name                           = "${var.cosmosdb_account_name}-psconn"
    private_connection_resource_id = azurerm_mongo_cluster.main.id
    is_manual_connection           = false
    subresource_names              = ["mongoCluster"]
  }

  private_dns_zone_group {
    name                 = data.azurerm_private_dns_zone.internal[0].name
    private_dns_zone_ids = [data.azurerm_private_dns_zone.internal[0].id]
  }

  tags = local.tags
}

# Azure Key Vault per salvare i secrets (bonus rispetto ad AWS — DynamoDB non ha vault nativo)
resource "azurerm_key_vault" "main" {
  count                       = var.enable_key_vault ? 1 : 0
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  public_network_access_enabled = var.enable_public_network_access == "Enabled" ? true : false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }

  tags = local.tags
}

resource "azurerm_key_vault_secret" "mongodb_connection_string" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "cosmosdb-mongodb-connection-string"
  value        = jsonencode(azurerm_mongo_cluster.main.connection_strings)
  key_vault_id = azurerm_key_vault.main[0].id
  depends_on   = [azurerm_key_vault.main]
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "mongodb_username" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "cosmosdb-mongodb-username"
  value        = var.mongodb_username
  key_vault_id = azurerm_key_vault.main[0].id
  depends_on   = [azurerm_key_vault.main]
  tags         = local.tags
}

resource "azurerm_key_vault_secret" "mongodb_password" {
  count        = var.enable_key_vault ? 1 : 0
  name         = "cosmosdb-mongodb-password"
  value        = var.mongodb_password
  key_vault_id = azurerm_key_vault.main[0].id
  depends_on   = [azurerm_key_vault.main]
  tags         = local.tags
}

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

# Storage Account per static website
resource "azurerm_storage_account" "website" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = var.account_tier
  account_replication_type = var.replication_type
  account_kind             = "StorageV2"

  # Abilita static website
  static_website {
    index_document     = var.index_document
    error_404_document = var.error_document
  }

  # Configurazioni di sicurezza
  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = true
  public_network_access_enabled   = true

  # Blob properties
  blob_properties {
    versioning_enabled  = var.enable_versioning
    change_feed_enabled = false

    dynamic "cors_rule" {
      for_each = var.enable_cors ? [1] : []
      content {
        allowed_headers    = var.cors_allowed_headers
        allowed_methods    = var.cors_allowed_methods
        allowed_origins    = var.cors_allowed_origins
        exposed_headers    = var.cors_exposed_headers
        max_age_in_seconds = var.cors_max_age_seconds
      }
    }

    dynamic "delete_retention_policy" {
      for_each = var.enable_soft_delete ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }
  }

  tags = var.tags
}

# Container $web viene creato automaticamente dalla configurazione static_website
# ma possiamo referenziarlo per caricare i file
data "azurerm_storage_account" "website" {
  name                = azurerm_storage_account.website.name
  resource_group_name = azurerm_resource_group.main.name
  depends_on          = [azurerm_storage_account.website]
}

# Upload index.html
resource "azurerm_storage_blob" "index" {
  name                   = var.index_document
  storage_account_name   = azurerm_storage_account.website.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = var.index_html_content
}

# Upload error.html
resource "azurerm_storage_blob" "error" {
  name                   = var.error_document
  storage_account_name   = azurerm_storage_account.website.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = var.error_html_content
}

# Upload file aggiuntivi
resource "azurerm_storage_blob" "website_files" {
  for_each = var.website_files

  name                   = each.key
  storage_account_name   = azurerm_storage_account.website.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = each.value.content_type
  source                 = each.value.source
}

# CDN Profile (opzionale, per HTTPS e performance)
resource "azurerm_cdn_profile" "website" {
  count               = var.enable_cdn ? 1 : 0
  name                = "${var.storage_account_name}-cdn"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.cdn_sku
  tags                = var.tags
}

# CDN Endpoint
resource "azurerm_cdn_endpoint" "website" {
  count               = var.enable_cdn ? 1 : 0
  name                = "${var.storage_account_name}-endpoint"
  profile_name        = azurerm_cdn_profile.website[0].name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  origin_host_header  = azurerm_storage_account.website.primary_web_host

  origin {
    name      = "website-origin"
    host_name = azurerm_storage_account.website.primary_web_host
  }

  delivery_rule {
    name  = "EnforceHTTPS"
    order = 1

    request_scheme_condition {
      match_values = ["HTTP"]
    }

    url_redirect_action {
      redirect_type = "Found"
      protocol      = "Https"
    }
  }

  is_compression_enabled = var.cdn_enable_compression
  content_types_to_compress = var.cdn_enable_compression ? [
    "text/plain",
    "text/html",
    "text/css",
    "application/x-javascript",
    "text/javascript",
    "application/javascript",
    "application/json",
    "application/xml"
  ] : []

  is_http_allowed  = true
  is_https_allowed = true

  tags = var.tags
}

# Custom Domain (opzionale)
resource "azurerm_cdn_endpoint_custom_domain" "website" {
  count           = var.enable_cdn && var.custom_domain_name != "" ? 1 : 0
  name            = replace(var.custom_domain_name, ".", "-")
  cdn_endpoint_id = azurerm_cdn_endpoint.website[0].id
  host_name       = var.custom_domain_name
}

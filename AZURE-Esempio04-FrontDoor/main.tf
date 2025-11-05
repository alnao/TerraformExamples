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

# Storage Account per contenuto statico
resource "azurerm_storage_account" "origin" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  static_website {
    index_document     = var.index_document
    error_404_document = var.error_document
  }

  tags = var.tags
}

# Upload file di esempio
resource "azurerm_storage_blob" "index" {
  name                   = var.index_document
  storage_account_name   = azurerm_storage_account.origin.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = var.index_html_content
}

resource "azurerm_storage_blob" "error" {
  name                   = var.error_document
  storage_account_name   = azurerm_storage_account.origin.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source_content         = var.error_html_content
}

# Azure Front Door (Standard o Premium)
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = var.frontdoor_name
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.frontdoor_sku
  tags                = var.tags
}

# Front Door Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = "${var.frontdoor_name}-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  tags                     = var.tags
}

# Origin Group
resource "azurerm_cdn_frontdoor_origin_group" "main" {
  name                     = "${var.frontdoor_name}-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 50
  }

  health_probe {
    protocol            = "Https"
    interval_in_seconds = var.health_probe_interval
    request_type        = "HEAD"
    path                = var.health_probe_path
  }
}

# Origin (Storage Account Static Website)
resource "azurerm_cdn_frontdoor_origin" "main" {
  name                          = "${var.frontdoor_name}-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  enabled                       = true

  certificate_name_check_enabled = true
  host_name                      = azurerm_storage_account.origin.primary_web_host
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_storage_account.origin.primary_web_host
  priority                       = 1
  weight                         = 1000
}

# Front Door Route
resource "azurerm_cdn_frontdoor_route" "main" {
  name                          = "${var.frontdoor_name}-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.main.id]
  
  supported_protocols    = var.supported_protocols
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = var.https_redirect_enabled

  # Cache configuration
  cdn_frontdoor_rule_set_ids = var.enable_caching ? [azurerm_cdn_frontdoor_rule_set.caching[0].id] : []
}

# Rule Set per caching (opzionale)
resource "azurerm_cdn_frontdoor_rule_set" "caching" {
  count                        = var.enable_caching ? 1 : 0
  name                         = "CachingRules"
  cdn_frontdoor_profile_id     = azurerm_cdn_frontdoor_profile.main.id
}

# Rule per file statici
resource "azurerm_cdn_frontdoor_rule" "static_files" {
  count                         = var.enable_caching ? 1 : 0
  name                          = "StaticFilesCaching"
  cdn_frontdoor_rule_set_id     = azurerm_cdn_frontdoor_rule_set.caching[0].id
  order                         = 1
  behavior_on_match             = "Continue"

  conditions {
    url_file_extension_condition {
      operator         = "Equal"
      match_values     = ["css", "js", "jpg", "jpeg", "png", "gif", "svg", "woff", "woff2", "ttf", "eot", "ico"]
      transforms       = ["Lowercase"]
    }
  }

  actions {
    route_configuration_override_action {
      cache_behavior                = "OverrideAlways"
      cache_duration                = var.static_files_cache_duration
      compression_enabled           = var.enable_compression
      query_string_caching_behavior = "IgnoreQueryString"
    }
  }
}

# Custom Domain (opzionale)
resource "azurerm_cdn_frontdoor_custom_domain" "main" {
  count                    = var.custom_domain_name != "" ? 1 : 0
  name                     = replace(var.custom_domain_name, ".", "-")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  dns_zone_id              = var.dns_zone_id
  host_name                = var.custom_domain_name

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = var.minimum_tls_version
  }
}

# Associate custom domain con route
resource "azurerm_cdn_frontdoor_custom_domain_association" "main" {
  count                          = var.custom_domain_name != "" ? 1 : 0
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.main[0].id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.main.id]
}

# Security Policy (WAF) - solo con Premium SKU
resource "azurerm_cdn_frontdoor_security_policy" "main" {
  count                    = var.enable_waf && var.frontdoor_sku == "Premium_AzureFrontDoor" ? 1 : 0
  name                     = "${var.frontdoor_name}-security-policy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.main[0].id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.main.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}

# WAF Policy
resource "azurerm_cdn_frontdoor_firewall_policy" "main" {
  count               = var.enable_waf && var.frontdoor_sku == "Premium_AzureFrontDoor" ? 1 : 0
  name                = replace("${var.frontdoor_name}wafpolicy", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.frontdoor_sku
  enabled             = true
  mode                = var.waf_mode

  # Managed rules
  managed_rule {
    type    = "DefaultRuleSet"
    version = "1.0"
    action  = "Block"
  }

  managed_rule {
    type    = "Microsoft_BotManagerRuleSet"
    version = "1.0"
    action  = "Block"
  }

  tags = var.tags
}

# Diagnostic Settings (opzionale)
resource "azurerm_monitor_diagnostic_setting" "frontdoor" {
  count                      = var.enable_diagnostic_settings ? 1 : 0
  name                       = "${var.frontdoor_name}-diagnostics"
  target_resource_id         = azurerm_cdn_frontdoor_profile.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "FrontDoorAccessLog"
  }

  enabled_log {
    category = "FrontDoorHealthProbeLog"
  }

  enabled_log {
    category = "FrontDoorWebApplicationFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Data sources per risorse esistenti necessarie al Private Endpoint
# Vengono caricati solo se enable_private_endpoint = true

data "azurerm_subnet" "private_endpoint" {
  count                = var.enable_private_endpoint ? 1 : 0
  name                 = var.private_endpoint_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.network_resource_group_name
}

data "azurerm_private_dns_zone" "internal" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = var.private_dns_zone_name
  resource_group_name = var.dns_resource_group_name
}


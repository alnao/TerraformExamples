terraform {
  backend "azurerm" {
    resource_group_name  = "alnao-terraform-resource-group"
    storage_account_name = "alnaoterraformstorage"
    container_name       = "alnao-terraform-blob-container"
    key                  = "esempio04frontdoor.tfstate"
  }
}

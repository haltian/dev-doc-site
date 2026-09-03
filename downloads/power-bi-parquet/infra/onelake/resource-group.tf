# Common data sources and random string generation

# Get current AzureRM authentication context (tenant and client IDs)
data "azurerm_client_config" "current" {}

# Optionally create the Resource Group
resource "azurerm_resource_group" "rg" {
  count    = var.create_resource_group ? 1 : 0
  name     = local.rg_name
  location = var.location
}

# Always access the Resource Group via data source
data "azurerm_resource_group" "rg" {
  name       = local.rg_name
  depends_on = [azurerm_resource_group.rg]
}
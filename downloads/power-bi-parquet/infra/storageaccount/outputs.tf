output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.rg.name
}

output "location" {
  description = "Azure region/location"
  value       = data.azurerm_resource_group.rg.location
}

output "subscription_id" {
  description = "Azure subscription ID"
  value       = data.azurerm_client_config.current.subscription_id
}

output "fabric_tenant_id" {
  description = "Azure AD tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "prefix" {
  description = "Base name/prefix used for resource naming"
  value       = local.base_name
}

output "storage_connection_string" {
  description = "Connection string for the upload storage account"
  value       = data.azurerm_storage_account.used_storage_account.primary_connection_string
  sensitive   = true
}

output "storage_account_url" {
  description = "URL of the upload storage account"
  value       = data.azurerm_storage_account.used_storage_account.primary_blob_endpoint
}

output "storage_container_name" {
  description = "Name of the upload container"
  value       = azurerm_storage_container.upload_container.name
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = data.azurerm_storage_account.used_storage_account.id
}

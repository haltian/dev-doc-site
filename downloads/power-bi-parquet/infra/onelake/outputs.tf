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
  value       = coalesce(var.fabric_tenant_id, data.azurerm_client_config.current.tenant_id)
}

output "prefix" {
  description = "Base name/prefix used for resource naming"
  value       = local.base_name
}

output "onelake_dfs_path" {
  description = "Expected OneLake DFS path prefix for the target Lakehouse Files container"
  value       = (local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? "https://onelake.dfs.fabric.microsoft.com/${fabric_workspace.workspace.display_name}/${fabric_lakehouse.lakehouse.display_name}/Files/${var.one_lake_subpath}" : "https://onelake.dfs.fabric.microsoft.com/${local.fabric_workspace_fqn}/${local.fabric_lakehouse_name}/Files/${var.one_lake_subpath}"
}

# Custom OneLake application outputs
output "onelake_app_client_id" {
  description = "Client ID of the custom OneLake application (for authentication)"
  value       = var.create_onelake_service_principal ? azuread_application.onelake_app[0].client_id : null
}

output "onelake_app_client_secret" {
  description = "Client secret of the custom OneLake application (for authentication)"
  value       = var.create_onelake_service_principal ? azuread_application_password.onelake_app_secret[0].value : null
  sensitive   = true
}

output "onelake_authentication_guide" {
  description = "Guide for using the custom OneLake application for authentication"
  value = var.create_onelake_service_principal ? {
    tenant_id     = coalesce(var.fabric_tenant_id, data.azurerm_client_config.current.tenant_id)
    client_id     = azuread_application.onelake_app[0].client_id
    client_secret = "<sensitive - use terraform output onelake_app_client_secret>"
    scope         = "https://onelake.dfs.fabric.microsoft.com/.default"
    instructions  = "Use these credentials in your local.settings.json to authenticate with OneLake and avoid AADSTS500011 errors"
  } : null
}

# Microsoft Fabric outputs
output "fabric_capacity_id" {
  description = "ID of the Microsoft Fabric capacity"
  value       = local.use_existing_capacity ? var.existing_fabric_capacity_id : (local.should_create_capacity ? azurerm_fabric_capacity.fabric[0].id : null)
}

output "fabric_workspace_id" {
  description = "ID of the Fabric workspace"
  value       = (local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? fabric_workspace.workspace.id : null
}

output "fabric_lakehouse_id" {
  description = "ID of the Fabric lakehouse"
  value       = (local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? fabric_lakehouse.lakehouse.id : null
}

output "fabric_workspace_name" {
  description = "Display name of the Fabric workspace"
  value       = (local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? fabric_workspace.workspace.display_name : local.fabric_workspace_fqn
}

output "fabric_lakehouse_name" {
  description = "Display name of the Fabric lakehouse"
  value       = (local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? fabric_lakehouse.lakehouse.display_name : local.fabric_lakehouse_name
}

output "fabric_setup_complete" {
  description = "Summary of created Fabric resources"
  value = (local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? {
    capacity_id    = local.use_existing_capacity ? var.existing_fabric_capacity_id : azurerm_fabric_capacity.fabric[0].id
    capacity_type  = local.use_existing_capacity ? "existing capacity" : "created capacity"
    workspace_name = fabric_workspace.workspace.display_name
    lakehouse_name = fabric_lakehouse.lakehouse.display_name
    onelake_url    = "https://onelake.dfs.fabric.microsoft.com/${fabric_workspace.workspace.display_name}/${fabric_lakehouse.lakehouse.display_name}/Files/${var.one_lake_subpath}"
    fabric_portal  = "https://app.fabric.microsoft.com/"
    status         = local.use_existing_capacity ? "Fabric workspace and lakehouse created using existing capacity" : "✅ Fabric capacity, workspace, and lakehouse created successfully"
    next_steps = [
      "1. Go to https://app.fabric.microsoft.com/",
      "2. Navigate to your workspace: ${fabric_workspace.workspace.display_name}",
      "3. Your lakehouse '${fabric_lakehouse.lakehouse.display_name}' should be ready for OneLake access",
      "4. Use the OneLake credentials from outputs for authentication"
    ]
    } : {
    capacity_id    = null
    capacity_type  = null
    workspace_name = null
    lakehouse_name = null
    onelake_url    = null
    fabric_portal  = "https://app.fabric.microsoft.com/"
    status         = "Fabric resources not created (disabled or OneLake not configured)"
    next_steps     = ["Enable Fabric capacity creation by setting create_fabric_capacity = true or provide existing_fabric_capacity_id"]
  }
}

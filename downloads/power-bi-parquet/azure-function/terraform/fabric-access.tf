# ==============================================================================
# Microsoft Fabric Workspace Access
# ==============================================================================
#
# Grant the service principal access to the Fabric workspace so it can write
# files to OneLake.
#
# ==============================================================================

# Look up the workspace by name
data "fabric_workspace" "target" {
  count        = var.use_fabric_service_principal == false ? 1 : 0
  display_name = var.fabric_workspace_fqn
}

# Grant the Function App's managed identity Contributor access to the workspace
resource "fabric_workspace_role_assignment" "func_managed_identity" {
  count        = var.use_fabric_service_principal == false ? 1 : 0
  workspace_id = data.fabric_workspace.target[0].id

  principal = {
    id   = azurerm_linux_function_app.func.identity[0].principal_id
    type = "ServicePrincipal"
  }

  role = "Contributor"
}

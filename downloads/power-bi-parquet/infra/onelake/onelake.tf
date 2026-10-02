# ==============================================================================
# OneLake Application and Permissions
# ==============================================================================

# Create a custom Azure AD application for OneLake access
resource "azuread_application" "onelake_app" {
  count        = var.create_onelake_service_principal ? 1 : 0
  display_name = "${local.base_name}-onelake-app"
  owners       = [data.azurerm_client_config.current.object_id]

  required_resource_access {
    resource_app_id = "2eac82a2-09ca-4bb6-9712-8c0e83213eae" # Microsoft OneLake DFS

    resource_access {
      id   = "c0ac6e9b-0b63-4d2d-8dd6-ca95a4d73e3e" # user_impersonation scope
      type = "Scope"
    }
  }
}

# Create service principal for the custom app
resource "azuread_service_principal" "onelake_app_sp" {
  count     = var.create_onelake_service_principal ? 1 : 0
  client_id = azuread_application.onelake_app[0].client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "fabric_workspace_role_assignment" "onelake_sp_contributor" {
  count = var.create_onelake_service_principal ? 1 : 0

  workspace_id = fabric_workspace.workspace.id
  principal = {
    id   = azuread_service_principal.onelake_app_sp[0].object_id
    type = "ServicePrincipal"
  }
  role = "Contributor"

  depends_on = [
    fabric_workspace.workspace,
    azuread_service_principal.onelake_app_sp
  ]
}

# Create a client secret for the service principal
resource "azuread_application_password" "onelake_app_secret" {
  count          = var.create_onelake_service_principal ? 1 : 0
  application_id = azuread_application.onelake_app[0].id
  display_name   = "OneLake Access Secret"
  end_date       = "2025-12-31T23:59:59Z"
}

# Grant admin consent for the OneLake permissions
# NOTE: This requires the OneLake DFS service principal to exist in the tenant
# If you encounter errors, you can grant consent manually via Azure Portal:
# Azure AD → App registrations → Find your app → API permissions → Grant admin consent
resource "azuread_service_principal_delegated_permission_grant" "onelake_consent" {
  count                                = 0 # Disabled - grant consent manually if needed
  service_principal_object_id          = azuread_service_principal.onelake_app_sp[0].object_id
  resource_service_principal_object_id = data.azuread_service_principal.onelake_dfs[0].object_id
  claim_values                         = ["user_impersonation"]
}

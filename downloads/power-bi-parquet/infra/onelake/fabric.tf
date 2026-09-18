# ==============================================================================
# Microsoft Fabric Resources
# ==============================================================================


# Try to find the Microsoft Fabric OneLake service principal in the tenant
# This is optional - only used for delegated permission grants
data "azuread_service_principal" "onelake_dfs" {
  count     = 0 # Disabled - Microsoft OneLake DFS app may not exist in all tenants
  client_id = "2eac82a2-09ca-4bb6-9712-8c0e83213eae" # Microsoft OneLake DFS
}

# Create Microsoft Fabric Capacity (when creating new capacity)
resource "azurerm_fabric_capacity" "fabric" {
  count               = local.should_create_capacity ? 1 : 0
  name                = local.fabric_capacity_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  sku {
    name = var.fabric_capacity_sku
    tier = "Fabric"
  }

  administration_members = length(var.fabric_capacity_admin_emails) > 0 ? var.fabric_capacity_admin_emails : [data.azurerm_client_config.current.object_id]

  tags = {
    Environment = "Demo"
    Purpose     = "S3 to OneLake data transfer"
    BaseName    = local.base_name
  }
}

# Locals for capacity reference
locals {
  # Get the capacity ID from either existing or created capacity
  fabric_capacity_id = local.use_existing_capacity ? var.existing_fabric_capacity_id : (local.should_create_capacity ? azurerm_fabric_capacity.fabric[0].id : null)
}

# Create Fabric Workspace
resource "fabric_workspace" "workspace" {
  display_name = local.fabric_workspace_fqn
  description  = "Workspace for ${local.base_name} S3 to OneLake data transfer"
  capacity_id  = local.fabric_capacity_id
}

# Create Lakehouse in the workspace
resource "fabric_lakehouse" "lakehouse" {
  display_name = local.fabric_lakehouse_name
  description  = "Lakehouse for S3 to OneLake data transfer"
  workspace_id = fabric_workspace.workspace.id

  depends_on = [fabric_workspace.workspace]
}

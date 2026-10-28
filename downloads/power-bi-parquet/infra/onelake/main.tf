# ==============================================================================
# OneLake and Microsoft Fabric Infrastructure Module
# ==============================================================================
#
# PURPOSE:
#   This Terraform configuration deploys Microsoft Fabric and OneLake infrastructure
#   components including:
#   - Microsoft Fabric Capacity (or use existing)
#   - Fabric Workspace
#   - Fabric Lakehouse
#   - OneLake application and service principal
#   - Azure AD permissions and role assignments
#   - Microsoft Graph API permissions
#
# COMPONENTS:
#   - onelake.tf             : OneLake application, service principal, and permissions
#   - fabric.tf              : Fabric capacity, workspace, and lakehouse resources
#   - admin-rbac.tf          : Azure subscription-level role assignments
#   - graph-permissions.tf   : Microsoft Graph API permissions and directory roles
#   - providers.tf           : Provider configurations (azurerm, azuread, fabric)
#   - common.tf              : Resource group and common data sources
#   - variables.tf           : Input variables (Fabric and OneLake specific)
#   - outputs.tf             : Output values (Fabric and OneLake resources)
#
# STATE:
#   Terraform state is stored locally in this directory (terraform.tfstate).
#   Each infrastructure module maintains its own independent state.
#
# REQUIRED VARIABLES:
#   - subscription_id                     : Azure subscription ID
#   - resource_group_name or prefix       : Resource group name or prefix
#   - fabric_tenant_id                    : Azure AD tenant ID (optional, auto-detected)
#
# OPTIONAL VARIABLES:
#   - create_fabric_capacity              : Whether to create new Fabric capacity (default: true)
#   - existing_fabric_capacity_id         : Use existing Fabric capacity instead
#   - fabric_capacity_sku                 : Fabric capacity SKU (default: F2)
#   - fabric_workspace_fqn                : Workspace name (default: derived from prefix)
#   - fabric_lakehouse_name               : Lakehouse name (default: derived from prefix)
#   - create_custom_onelake_app           : Create custom OneLake AAD app (default: true)
#   - assign_directory_roles              : Assign directory roles (default: true)
#   - assign_graph_permissions            : Assign Graph permissions (default: true)
#   - create_custom_roles                 : Create custom Azure roles (default: true)
#
# OUTPUTS:
#   - resource_group_name                 : Name of the resource group
#   - onelake_dfs_path                    : OneLake DFS path for accessing the lakehouse
#   - onelake_app_client_id               : Client ID for OneLake authentication
#   - onelake_app_client_secret           : Client secret for OneLake authentication (sensitive)
#   - fabric_capacity_id                  : ID of the Fabric capacity
#   - fabric_workspace_id                 : ID of the Fabric workspace
#   - fabric_lakehouse_id                 : ID of the Fabric lakehouse
#   - fabric_workspace_name               : Display name of the workspace
#   - fabric_lakehouse_name               : Display name of the lakehouse
#   - fabric_setup_complete               : Summary of deployment status
#
# USAGE:
#   1. Create a terraform.tfvars file with your configuration:
#      ```
#      subscription_id        = "your-subscription-id"
#      resource_group_name    = "my-fabric-rg"
#      create_resource_group  = true
#      location               = "westeurope"
#      fabric_tenant_id       = "your-tenant-id"
#      fabric_capacity_sku    = "F2"
#      ```
#
#   2. Initialize Terraform:
#      ```
#      terraform init
#      ```
#
#   3. Plan the deployment:
#      ```
#      terraform plan
#      ```
#
#   4. Apply the configuration:
#      ```
#      terraform apply
#      ```
#
#   5. Retrieve outputs:
#      ```
#      terraform output
#      terraform output -raw onelake_app_client_secret
#      ```
#
# DEPLOYMENT ORDER:
#   This module can be deployed independently. However, if you're deploying the
#   full solution, the recommended order is:
#   1. infra/azuredisk      (Azure Storage for data landing)
#   2. infra/onelake        (This module - Fabric and OneLake infrastructure)
#   3. azure-function/terraform (Function App deployment)
#
# ==============================================================================

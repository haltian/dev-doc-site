variable "prefix" {
  description = "Optional short prefix for resource names (3-10 lowercase alphanumerics). If not set, derived from resource_group_name."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "subscription_id" {
  description = "Azure subscription ID to deploy into. Optional; if not set, the subscription from your current Azure authentication context is used."
  type        = string
  default     = null
}

variable "resource_group_name" {
  description = "Resource Group name to use or create. If not set, one will be generated from prefix."
  type        = string
  default     = null
}

variable "create_resource_group" {
  description = "Whether to create the resource group if it does not exist. When false, an existing RG with the given or derived name must exist."
  type        = bool
  default     = false
}

variable "create_onelake_service_principal" {
  description = "Whether to create a custom Azure AD application with OneLake permissions for authentication."
  type        = bool
  default     = true
}

variable "create_fabric_capacity" {
  description = "Whether to create a Microsoft Fabric capacity. Required for OneLake functionality."
  type        = bool
  default     = true
}

variable "fabric_capacity_sku" {
  description = "SKU for the Microsoft Fabric capacity (F2, F4, F8, F16, F32, F64, etc.). F2 is the smallest paid SKU."
  type        = string
  default     = "F2"
}

variable "fabric_capacity_admin_emails" {
  description = "List of email addresses that should be admins of the Fabric capacity. Defaults to current user."
  type        = list(string)
  default     = []
}

variable "existing_fabric_capacity_id" {
  description = "ID of an existing Fabric capacity to use instead of creating a new one. If provided, create_fabric_capacity will be ignored."
  type        = string
  default     = null
}

# Azure Service Principal authentication (optional)
variable "az_service_principal_application_id" {
  description = "Azure Service Principal Application ID (Client ID). If not set, uses Azure CLI authentication."
  type        = string
  default     = null
}

variable "az_service_principal_password" {
  description = "Azure Service Principal Password (Client Secret). If not set, uses Azure CLI authentication."
  type        = string
  sensitive   = true
  default     = null
}

# RBAC Configuration Variables
variable "assign_directory_roles" {
  description = "Whether to assign directory roles (Application Administrator, Fabric Administrator) to the service principal. Requires Global Admin privileges."
  type        = bool
  default     = true
}

variable "assign_graph_permissions" {
  description = "Whether to assign Microsoft Graph API permissions to the service principal."
  type        = bool
  default     = true
}

variable "create_custom_roles" {
  description = "Whether to create custom Azure roles with enhanced permissions."
  type        = bool
  default     = true
}

# Fabric / OneLake settings
variable "fabric_tenant_id" {
  description = "Microsoft Entra ID (AAD) tenant ID. If not set, derived from the currently authenticated AzureRM context."
  type        = string
  default     = null
}

variable "fabric_client_id" {
  description = "AAD app client ID for OneLake access. If not set, derived from the currently authenticated AzureRM context."
  type        = string
  default     = null
}

variable "fabric_client_secret" {
  description = "AAD app client secret for OneLake access. Optional when using Managed Identity."
  type        = string
  sensitive   = true
  default     = null
}

variable "fabric_workspace_fqn" {
  description = "Fabric Workspace FQN (display name or fully qualified name). If not set, derived from base name."
  type        = string
  default     = null
}

variable "fabric_lakehouse_name" {
  description = "Fabric Lakehouse name. If not set, derived from base name."
  type        = string
  default     = null
}

variable "one_lake_subpath" {
  description = "Optional subpath under /Files/ to write into (e.g., incoming/)"
  type        = string
  default     = ""
}

locals {
  # Derive a normalized base from either explicit prefix, RG name (without -rg), or fallback
  raw_base  = var.prefix != null && var.prefix != "" ? var.prefix : (var.resource_group_name != null && var.resource_group_name != "" ? trimsuffix(var.resource_group_name, "-rg") : "s3onelake")
  base_name = lower(replace(local.raw_base, "/[^a-z0-9]/", ""))

  # Canonical resource group name accessor
  rg_name = coalesce(var.resource_group_name, "rg-${local.base_name}")

  # Fabric capacity name - must be 3-63 chars, lowercase letters and numbers only, start with letter
  # Create meaningful name by removing special characters and adding 'fabric' suffix
  fabric_capacity_name = lower(replace("${local.base_name}fabric", "/[^a-z0-9]/", ""))

  # Fabric naming derived centrally for followability
  # Workspace names can contain dashes, lakehouse names cannot contain special characters
  fabric_workspace_fqn  = coalesce(var.fabric_workspace_fqn, "${local.base_name}-workspace")
  fabric_lakehouse_name = coalesce(var.fabric_lakehouse_name, lower(replace("${local.base_name}lakehouse", "/[^a-z0-9]/", "")))

  # Auto-detect if OneLake configuration is present and selected
  onelake_configured = local.fabric_workspace_fqn != null && local.fabric_lakehouse_name != null


  # Determine whether to use existing capacity or create new one
  use_existing_capacity  = var.existing_fabric_capacity_id != null && var.existing_fabric_capacity_id != ""
  should_create_capacity = var.create_fabric_capacity && !local.use_existing_capacity && local.onelake_configured
}

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

variable "fabric_tenant_id" {
  description = "Azure AD tenant ID. If not set, derived from the currently authenticated AzureRM context."
  type        = string
  default     = null
}

# Storage Account upload options
variable "storage_use_existing" {
  description = "Use an existing storage account instead of creating one"
  type        = bool
  default     = false
}

variable "existing_storage_account_name" {
  description = "Name of an existing storage account to upload into (required when storage_use_existing=true)"
  type        = string
  default     = null
}

variable "existing_storage_account_rg" {
  description = "Resource group of the existing storage account (required when storage_use_existing=true)"
  type        = string
  default     = null
}

variable "upload_storage_account_name" {
  description = "Optional name for a new storage account to create for uploads (used when storage_use_existing=false). If null, a name will be generated."
  type        = string
  default     = null
}

variable "upload_storage_container_name" {
  description = "Container name to upload into (created if not exists when creating new account)."
  type        = string
  default     = "incoming"
}

variable "upload_subpath" {
  description = "Optional subpath within the upload target."
  type        = string
  default     = ""
}

variable "blob_readers_id" {
  description = "List of principal IDs (User Object IDs, Service Principal IDs, or Managed Identity IDs) to grant Storage Blob Data Reader role on the storage account"
  type        = list(string)
  default     = []
}

variable "blob_readers_email" {
  description = "List of email addresses (users or service principals) to grant Storage Blob Data Reader role on the storage account. These will be looked up to their corresponding object IDs."
  type        = list(string)
  default     = []
}

locals {
  # Derive a normalized base from either explicit prefix, RG name (without -rg), or fallback
  raw_base  = var.prefix != null && var.prefix != "" ? var.prefix : (var.resource_group_name != null && var.resource_group_name != "" ? trimsuffix(var.resource_group_name, "-rg") : "s3onelake")
  base_name = lower(replace(local.raw_base, "/[^a-z0-9]/", ""))

  # Canonical resource group name accessor
  rg_name = coalesce(var.resource_group_name, "${local.base_name}-rg")
}

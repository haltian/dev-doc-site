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

# S3 settings
variable "s3_access_key_id" {
  description = "AWS access key id with read access to the bucket"
  type        = string
  sensitive   = true
}

variable "s3_secret_access_key" {
  description = "AWS secret access key with read access to the bucket"
  type        = string
  sensitive   = true
}

variable "s3_region" {
  description = "AWS region of the S3 bucket"
  type        = string
  default     = "us-east-1"
}

variable "s3_bucket" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "s3_prefix" {
  description = "Optional prefix inside the bucket to scope the copy (e.g., parquet/)"
  type        = string
  default     = ""
}

# Timer trigger schedule for the Azure Function
variable "copy_parquet_schedule" {
  description = "CRON-with-seconds schedule for the timer trigger (Azure Functions). Example: \"0 */15 * * * *\" for every 15 minutes."
  type        = string
}


variable "measurements_time_range_days" {
  description = "Number of days to look back when selecting measurements."
  type        = string
  default     = "14"
}


variable "log_level" {
  description = "Logging level for the function (DEBUG, INFO, WARNING, ERROR, CRITICAL)"
  type        = string
  default     = "INFO"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], var.log_level)
    error_message = "log_level must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL."
  }
}

# Upload target selection
variable "upload_type" {
  description = "Where to upload parquet files: 'onelake' or 'storageaccount'"
  type        = string
  default     = "onelake"
  validation {
    condition     = contains(["onelake", "storageaccount"], var.upload_type)
    error_message = "upload_type must be 'onelake' or 'storageaccount'."
  }
}

variable "upload_subpath" {
  description = "Optional subpath within the upload target."
  type        = string
  default     = ""
}

# OneLake/Fabric settings (passed from infra/onelake outputs)
variable "fabric_client_id" {
  description = "AAD app client ID for OneLake access (from infra/onelake outputs)."
  type        = string
  default     = null
}

variable "fabric_client_secret" {
  description = "AAD app client secret for OneLake access (from infra/onelake outputs)."
  type        = string
  sensitive   = true
  default     = null
}

variable "fabric_workspace_fqn" {
  description = "Fabric Workspace FQN/display name (from infra/onelake outputs)."
  type        = string
  default     = null
}

variable "fabric_workspace_id" {
  description = "Fabric Workspace ID/GUID (from infra/onelake outputs or Fabric portal)."
  type        = string
  default     = null
}

variable "fabric_lakehouse_name" {
  description = "Fabric Lakehouse name (from infra/onelake outputs)."
  type        = string
  default     = null
}

variable "fabric_lakehouse_id" {
  description = "Fabric Lakehouse ID/GUID (from infra/onelake outputs or Fabric portal)."
  type        = string
  default     = null
}

variable "one_lake_subpath" {
  description = "Optional subpath under /Files/ to write into (from infra/onelake outputs)."
  type        = string
  default     = ""
}

# Storage Account settings (passed from infra/storageaccount outputs)
variable "storage_connection_string" {
  description = "Storage account connection string (from infra/storageaccount outputs)."
  type        = string
  sensitive   = true
  default     = null
}

variable "storage_account_url" {
  description = "Storage account URL (from infra/storageaccount outputs)."
  type        = string
  default     = null
}

variable "use_fabric_service_principal" {
  type = bool
  default = null
}

variable "upload_storage_container" {
  description = "Container name for uploads (from infra/storageaccount outputs)."
  type        = string
  default     = null
}

locals {
  # Derive a normalized base from either explicit prefix, RG name (without -rg), or fallback
  raw_base  = var.prefix != null && var.prefix != "" ? var.prefix : (var.resource_group_name != null && var.resource_group_name != "" ? trimsuffix(var.resource_group_name, "-rg") : "s3onelake")
  base_name = lower(replace(local.raw_base, "/[^a-z0-9]/", ""))

  # Canonical resource group name accessor
  rg_name = coalesce(var.resource_group_name, "${local.base_name}-rg")

  # Upload type helpers
  use_onelake = var.upload_type == "onelake"
  use_storage = var.upload_type == "storageaccount"
}

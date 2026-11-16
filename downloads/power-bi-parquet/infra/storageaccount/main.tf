# ==============================================================================
# Azure Storage Account Infrastructure Module
# ==============================================================================
#
# PURPOSE:
#   This Terraform configuration deploys Azure Storage Account infrastructure
#   for data uploads including:
#   - Azure Storage Account (new or existing)
#   - Storage Container for data landing
#   - Access configuration and connection strings
#
# COMPONENTS:
#   - providers.tf       : Provider configurations (azurerm)
#   - main.tf            : Resource group. Storage account, container resources and common data sources
#   - variables.tf       : Input variables (storage-specific)
#   - outputs.tf         : Output values (storage connection details)
#
# STATE:
#   Terraform state is stored locally in this directory (terraform.tfstate).
#   Each infrastructure module maintains its own independent state.
#
# REQUIRED VARIABLES:
#   - subscription_id                     : Azure subscription ID
#   - resource_group_name or prefix       : Resource group name or prefix
#
# OPTIONAL VARIABLES:
#   - storage_use_existing                : Use existing storage account (default: false)
#   - existing_storage_account_name       : Name of existing storage account
#   - existing_storage_account_rg         : Resource group of existing storage account
#   - upload_storage_account_name         : Name for new storage account (auto-generated if not set)
#   - upload_storage_container_name       : Container name (default: "incoming")
#   - upload_subpath                      : Subpath within the container
#   - location                            : Azure region (default: "westeurope")
#
# OUTPUTS:
#   - resource_group_name                 : Name of the resource group
#   - storage_connection_string           : Connection string for the storage account (sensitive)
#   - storage_account_url                 : URL of the storage account
#   - storage_container_name              : Name of the container
#   - storage_account_name                : Name of the storage account
#
# USAGE:
#   1. Create a terraform.tfvars file with your configuration:
#      ```
#      subscription_id        = "your-subscription-id"
#      resource_group_name    = "my-storage-rg"
#      create_resource_group  = true
#      location               = "westeurope"
#      upload_storage_container_name = "incoming"
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
#      terraform output -raw storage_connection_string
#      ```
#
# DEPLOYMENT ORDER:
#   This module can be deployed independently. However, if you're deploying the
#   full solution, the recommended order is:
#   1. infra/azuredisk      (This module - Azure Storage for data landing)
#   2. azure-function/terraform (Function App deployment)
#
# ==============================================================================

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

# Create a dedicated storage account for uploads when not using existing
resource "azurerm_storage_account" "upload_sa" {
  count                           = !var.storage_use_existing ? 1 : 0
  name                            = coalesce(var.upload_storage_account_name, substr(replace("${local.base_name}uploadstorage", "-", ""), 0, 24))
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = data.azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

# Use existing storage account, either one created above or existing before
data "azurerm_storage_account" "used_storage_account" {
  name                = var.storage_use_existing ? var.existing_storage_account_name : azurerm_storage_account.upload_sa[0].name
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_storage_container" "upload_container" {
  name                  = var.upload_storage_container_name
  storage_account_id    = data.azurerm_storage_account.used_storage_account.id
  container_access_type = "private"
}

# Lookup users by email to get their object IDs
data "azuread_user" "blob_readers" {
  count               = length(var.blob_readers_email)
  user_principal_name = var.blob_readers_email[count.index]
}

# Expose locals for app settings
locals {
  # Combine direct IDs and looked-up IDs from emails
  blob_reader_principal_ids = concat(
    var.blob_readers_id,
    [for user in data.azuread_user.blob_readers : user.object_id]
  )
}

# Grant Storage Blob Data Reader role to configured principals
resource "azurerm_role_assignment" "blob_readers" {
  count                = length(local.blob_reader_principal_ids)
  scope                = data.azurerm_storage_account.used_storage_account.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = local.blob_reader_principal_ids[count.index]

  depends_on = [
    azurerm_storage_account.upload_sa,
    azurerm_storage_container.upload_container,
    data.azurerm_storage_account.used_storage_account
  ]
}

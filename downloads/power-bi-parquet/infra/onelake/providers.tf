terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.47.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
    fabric = {
      source  = "microsoft/fabric"
      version = ">= 0.1.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.az_service_principal_application_id
  client_secret   = var.az_service_principal_password
  tenant_id       = var.fabric_tenant_id
}

provider "azuread" {
  # tenant_id will be auto-detected from current context if not specified
  tenant_id = var.fabric_tenant_id
}

provider "fabric" {
  # Use Azure CLI authentication for admin privileges
  tenant_id = var.fabric_tenant_id
  # No client_id/client_secret specified - uses Azure CLI authentication
}

# Separate provider alias for global admin operations using Azure CLI authentication
# This provider uses the current Azure CLI authentication context which should have Global Admin rights
provider "azuread" {
  alias     = "admin"
  tenant_id = var.fabric_tenant_id
  # No client_id/client_secret specified - uses Azure CLI authentication
}

provider "azurerm" {
  alias = "admin"
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.fabric_tenant_id
  # No client_id/client_secret specified - uses Azure CLI authentication
}

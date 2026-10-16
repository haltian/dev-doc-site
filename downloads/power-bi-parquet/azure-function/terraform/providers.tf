terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
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

provider "fabric" {
  # Use Azure CLI authentication for Fabric API access
  tenant_id = var.fabric_tenant_id
}

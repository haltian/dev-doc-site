# ==============================================================================
# Azure Function App Deployment Module
# ==============================================================================
#
# PURPOSE:
#   This Terraform configuration deploys the Azure Function App and related
#   monitoring resources including:
#   - Azure Function App (Linux, Python 3.10)
#   - App Service Plan (Consumption tier)
#   - Application Insights for monitoring
#   - Log Analytics Workspace
#   - Storage Account for Function App runtime
#   - Managed Identity for the Function App
#
# COMPONENTS:
#   - function-app.tf   : Function App, App Service Plan, monitoring resources
#   - providers.tf      : Provider configurations (azurerm, archive)
#   - common.tf         : Resource group and common data sources
#   - variables.tf      : Input variables (function and app settings)
#   - outputs.tf        : Output values (function app details and monitoring)
#
# STATE:
#   Terraform state is stored locally in this directory (terraform.tfstate).
#   Each module maintains its own independent state.
#
# REQUIRED VARIABLES:
#   - subscription_id                     : Azure subscription ID
#   - resource_group_name or prefix       : Resource group name or prefix
#   - s3_access_key_id                    : AWS S3 access key
#   - s3_secret_access_key                : AWS S3 secret key
#   - s3_bucket                           : AWS S3 bucket name
#   - copy_parquet_schedule               : CRON schedule for copy function
#
# OPTIONAL VARIABLES (from infra modules):
#   - fabric_client_id                    : From infra/onelake outputs
#   - fabric_client_secret                : From infra/onelake outputs
#   - fabric_workspace_fqn                : From infra/onelake outputs
#   - fabric_lakehouse_name               : From infra/onelake outputs
#   - one_lake_subpath                    : From infra/onelake outputs
#   - storage_connection_string           : From infra/azuredisk outputs
#   - storage_account_url                 : From infra/azuredisk outputs
#   - upload_storage_container            : From infra/azuredisk outputs
#
# OTHER OPTIONAL VARIABLES:
#   - upload_type                         : "onelake" or "storageaccount" (default: onelake)
#   - create_tables_schedule              : CRON schedule for create_tables
#   - create_tables_timeout_seconds       : Timeout for Spark jobs (default: 600)
#   - s3_region                           : AWS region (default: us-east-1)
#   - s3_prefix                           : S3 prefix filter
#   - location                            : Azure region (default: westeurope)
#
# OUTPUTS:
#   - function_app_name                   : Name of the Function App
#   - function_app_default_hostname       : Hostname for the Function App
#   - function_app_id                     : Resource ID of the Function App
#   - function_app_identity_principal_id  : Managed Identity principal ID
#   - application_insights_app_id         : App Insights application ID
#   - application_insights_instrumentation_key : App Insights instrumentation key (sensitive)
#   - log_analytics_workspace_id          : Log Analytics workspace ID
#   - resource_group_name                 : Resource group name
#
# USAGE:
#   1. Deploy infrastructure first:
#      - infra/azuredisk (if using storage account)
#      - infra/onelake (if using OneLake)
#
#   2. Create a terraform.tfvars file with your configuration:
#      ```
#      subscription_id        = "your-subscription-id"
#      resource_group_name    = "my-function-rg"
#      create_resource_group  = true
#      location               = "westeurope"
#
#      # S3 settings
#      s3_access_key_id       = "your-s3-key"
#      s3_secret_access_key   = "your-s3-secret"
#      s3_bucket              = "<BUCKET>"
#      s3_region              = "us-east-1"
#      copy_parquet_schedule  = "0 */15 * * * *"
#
#      # OneLake settings (from infra/onelake outputs)
#      upload_type            = "onelake"
#      fabric_client_id       = "output-from-onelake-module"
#      fabric_client_secret   = "output-from-onelake-module"
#      fabric_workspace_fqn   = "output-from-onelake-module"
#      fabric_lakehouse_name  = "output-from-onelake-module"
#
#      # OR Storage Account settings (from infra/azuredisk outputs)
#      # upload_type                = "storageaccount"
#      # storage_connection_string  = "output-from-azuredisk-module"
#      # storage_account_url        = "output-from-azuredisk-module"
#      # upload_storage_container   = "output-from-azuredisk-module"
#      ```
#
#   3. Initialize Terraform:
#      ```
#      terraform init
#      ```
#
#   4. Plan the deployment:
#      ```
#      terraform plan
#      ```
#
#   5. Apply the configuration:
#      ```
#      terraform apply
#      ```
#
#   6. Retrieve outputs:
#      ```
#      terraform output
#      ```
#
# DEPLOYMENT ORDER:
#   The recommended deployment order for the full solution:
#   1. infra/azuredisk      (Azure Storage for data landing) - if using storageaccount
#   2. infra/onelake        (Fabric and OneLake infrastructure) - if using onelake
#   3. azure-function/terraform (This module - Function App deployment)
#
# NOTES:
#   - The Function App uses a Managed Identity for Azure resource access
#   - Application code is packaged from the ../azure-function directory
#   - Logs and metrics are available in Application Insights
#   - Function App settings are configured based on upload_type selection
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

# Storage account for the Function App state
resource "azurerm_storage_account" "func_sa" {
  name                            = substr(replace("${local.base_name}statestorage", "-", ""), 0, 24)
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = data.azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

# Application Insights for Function App monitoring
resource "azurerm_log_analytics_workspace" "func_logs" {
  name                = "${local.base_name}-logs"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    Environment = "Demo"
    Purpose     = "Function App Monitoring"
    BaseName    = local.base_name
  }
}

resource "azurerm_application_insights" "func_insights" {
  name                = "${local.base_name}-insights"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.func_logs.id
  application_type    = "other"

  tags = {
    Environment = "Demo"
    Purpose     = "Function App Monitoring"
    BaseName    = local.base_name
  }
}

# App Service Plan for the Function App
resource "azurerm_service_plan" "plan" {
  name                = "${local.base_name}-plan"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption (classic)
}

# Package the Azure Function code
data "archive_file" "function_package" {
  type        = "zip"
  source_dir  = "${path.module}/.."
  output_path = "${path.module}/functionapp.zip"
  excludes = [
    ".git",
    ".git/**",
    ".gitignore",
    ".vscode",
    ".vscode/**",
    "venv",
    "venv/**",
    ".venv",
    ".venv/**",
    "local.settings.json",
    "__pycache__",
    "__pycache__/**",
    ".python_packages",
    ".python_packages/**",
    "tests",
    "tests/**",
    "test_onelake.py",
    "terraform",
    "terraform/**",
    ".pytest_cache",
    ".pytest_cache/**",
    "run_from_ide.py",
    "*.md",
    ".funcignore",
    "*.pyc",
    "**/__pycache__/**",
    "**/test_*.py",
    "**/*.pyc"
  ]
}

# Linux Function App
resource "azurerm_linux_function_app" "func" {
  name                          = "${local.base_name}-func"
  location                      = data.azurerm_resource_group.rg.location
  resource_group_name           = data.azurerm_resource_group.rg.name
  service_plan_id               = azurerm_service_plan.plan.id
  storage_account_name          = azurerm_storage_account.func_sa.name
  storage_account_access_key    = azurerm_storage_account.func_sa.primary_access_key
  public_network_access_enabled = true # Required for zip deployment

  site_config {
    application_stack {
      python_version = "3.10"
    }
    use_32_bit_worker = false
    http2_enabled     = true

    # Enable remote build for Python dependencies
    scm_use_main_ip_restriction = false
  }

  # Deploy function code
  zip_deploy_file = data.archive_file.function_package.output_path

  # Application settings
  app_settings = merge(
    {
      FUNCTIONS_WORKER_RUNTIME       = "python"
      FUNCTIONS_EXTENSION_VERSION    = "~4"
      AzureWebJobsStorage            = azurerm_storage_account.func_sa.primary_connection_string
      ENABLE_ORYX_BUILD              = "true"
      SCM_DO_BUILD_DURING_DEPLOYMENT = "true"

      # Application Insights integration
      APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.func_insights.instrumentation_key
      APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.func_insights.connection_string
      ApplicationInsightsAgent_EXTENSION_VERSION = "~3"

      # S3 source settings
      S3_ACCESS_KEY_ID     = var.s3_access_key_id
      S3_SECRET_ACCESS_KEY = var.s3_secret_access_key
      S3_REGION            = var.s3_region
      S3_BUCKET            = var.s3_bucket
      S3_PREFIX            = var.s3_prefix

      # Upload selection
      UPLOAD_TYPE = var.upload_type

      MEASUREMENTS_TIME_RANGE_DAYS = var.measurements_time_range_days
      COPY_PARQUET_SCHEDULE        = var.copy_parquet_schedule

      # Logging configuration
      LOG_LEVEL = var.log_level
    },
    # OneLake-specific settings (only when selected)
      local.use_onelake ? {
      FABRIC_TENANT_ID      = coalesce(var.fabric_tenant_id, data.azurerm_client_config.current.tenant_id)
      FABRIC_CLIENT_ID      = coalesce(var.fabric_client_id, data.azurerm_client_config.current.client_id)
      FABRIC_WORKSPACE_FQN  = var.fabric_workspace_fqn
      FABRIC_LAKEHOUSE_NAME = var.fabric_lakehouse_name
      ONE_LAKE_SUBPATH      = coalesce(var.one_lake_subpath, var.upload_subpath, "")
    } : {},
      (local.use_onelake && var.fabric_client_secret != null && var.fabric_client_secret != "") ? {
      FABRIC_CLIENT_SECRET = var.fabric_client_secret
    } : {},
    # Storage Account-specific settings (only when selected)
      local.use_storage ? {
      # Prefer connection string if available, else account URL with MSI
      STORAGE_CONNECTION_STRING = var.storage_connection_string
      STORAGE_ACCOUNT_URL       = var.storage_account_url
      STORAGE_UPLOAD_CONTAINER  = var.upload_storage_container
      UPLOAD_SUBPATH            = var.upload_subpath
    } : {}
  )

  identity {
    type = "SystemAssigned"
  }

}

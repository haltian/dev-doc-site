
# Generate Function App tfvars template
output "function_app_template_tfvars" {
  description = "Template tfvars file for Function App deployment with OneLake configuration"
  sensitive   = true
  value = <<-EOT
# ==============================================================================
# Azure Function App Configuration - from terraform output ${local.base_name}
# ==============================================================================

# NOTE: if going for DEBUG, it might increase the application analytics and insight costs, as the DEBUG level is very verbose.
log_level = "INFO"

# Azure Subscription Settings
subscription_id        = "${data.azurerm_client_config.current.subscription_id}"
fabric_tenant_id       = "${var.fabric_tenant_id}"

# Resource Group Configuration
resource_group_name    = "${data.azurerm_resource_group.rg.name}"
create_resource_group  = false

# Naming
prefix                 = "${local.base_name}"

# AWS S3 Configuration
s3_access_key_id       = "YOUR_S3_ACCESS_KEY_ID"
s3_secret_access_key   = "YOUR_S3_SECRET_ACCESS_KEY"
s3_bucket              = "YOUR_S3_BUCKET_NAME"
s3_region              = "YOUR_S3_REGION"  # e.g., eu-west-1, us-east-1
s3_prefix              = ""  # Optional: prefix/path within bucket

# Function Schedule (CRON format with seconds)
copy_parquet_schedule  = "0 */2 * * * *"  # Every 2 minutes
measurements_time_range_days = "14"        # Days to look back for measurements (1-365)

# Upload Target
upload_type            = "onelake"

# OneLake Deployment Outputs
%{if var.create_onelake_service_principal~}
use_fabric_service_principal = true
fabric_client_id       = "${azuread_application.onelake_app[0].client_id}"
fabric_client_secret   = "${azuread_application_password.onelake_app_secret[0].value}"
%{else~}
use_fabric_service_principal = false
%{endif~}
fabric_workspace_fqn   = "${(local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? fabric_workspace.workspace.display_name : local.fabric_workspace_fqn}"
fabric_lakehouse_name  = "${(local.use_existing_capacity || local.should_create_capacity) && local.onelake_configured ? fabric_lakehouse.lakehouse.display_name : local.fabric_lakehouse_name}"

one_lake_subpath       = "upload/"

# Optional: Service Principal Authentication (if using SP instead of Azure CLI)
%{if var.az_service_principal_application_id != null && var.az_service_principal_application_id != ""~}
az_service_principal_application_id = "${var.az_service_principal_application_id}"
az_service_principal_password       = "${var.az_service_principal_password}"
%{else~}
# az_service_principal_application_id = "YOUR_SP_CLIENT_ID"
# az_service_principal_password       = "YOUR_SP_CLIENT_SECRET"
%{endif~}
EOT
}

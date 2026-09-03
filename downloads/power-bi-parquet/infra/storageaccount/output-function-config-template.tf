## Generate Function App tfvars template for Storage Account path
output "function_app_template_tfvars" {
  description = "Template tfvars file for Function App deployment with Storage Account configuration"
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
upload_type            = "storageaccount"

# Storage Deployment Outputs
storage_connection_string = "${data.azurerm_storage_account.used_storage_account.primary_connection_string}"
storage_account_url       = "${data.azurerm_storage_account.used_storage_account.primary_blob_endpoint}"
upload_storage_container  = "${azurerm_storage_container.upload_container.name}"
upload_subpath            = "${var.upload_subpath}"

# Optional: Service Principal Authentication (if using SP instead of Azure CLI)
# az_service_principal_application_id = "YOUR_SP_CLIENT_ID"
# az_service_principal_password       = "YOUR_SP_CLIENT_SECRET"
EOT
}

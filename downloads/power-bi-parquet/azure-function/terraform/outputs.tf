output "function_app_name" {
  description = "Name of the Azure Function App"
  value       = azurerm_linux_function_app.func.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = azurerm_linux_function_app.func.default_hostname
}

output "function_app_id" {
  description = "ID of the Function App"
  value       = azurerm_linux_function_app.func.id
}

output "function_app_identity_principal_id" {
  description = "Principal ID of the Function App's managed identity"
  value       = azurerm_linux_function_app.func.identity[0].principal_id
}

output "application_insights_app_id" {
  description = "Application Insights Application ID"
  value       = azurerm_application_insights.func_insights.app_id
}

output "application_insights_instrumentation_key" {
  description = "Application Insights Instrumentation Key"
  value       = azurerm_application_insights.func_insights.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights Connection String"
  value       = azurerm_application_insights.func_insights.connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for Application Insights"
  value       = azurerm_log_analytics_workspace.func_logs.id
}

output "function_address" {
  description = "Log Analytics Workspace ID for Application Insights"
  value       = "https://portal.azure.com/#@/resource${azurerm_linux_function_app.func.id}"
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.rg.name
}

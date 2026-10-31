output "production_url" {
  description = "Where to reach the production slot (the web app itself) in a browser."
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "staging_url" {
  description = "Where to reach the staging slot in a browser."
  value       = "https://${azurerm_linux_web_app_slot.staging.default_hostname}"
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = azurerm_resource_group.main.name
}

output "web_app" {
  description = "The name of the web app whose slots are swapped."
  value       = azurerm_linux_web_app.main.name
}

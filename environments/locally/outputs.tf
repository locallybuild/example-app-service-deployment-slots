output "production_url" {
  description = "Where to reach the production slot (the web app itself) in a browser."
  value       = module.app-service-deployment-slots.production_url
}

output "staging_url" {
  description = "Where to reach the staging slot in a browser."
  value       = module.app-service-deployment-slots.staging_url
}

output "resource_group" {
  description = "The resource group containing the deployed resources."
  value       = module.app-service-deployment-slots.resource_group
}

output "web_app" {
  description = "The name of the web app whose slots are swapped."
  value       = module.app-service-deployment-slots.web_app
}

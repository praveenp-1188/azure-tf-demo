output "resource_group" {
  value = azurerm_resource_group.this.name
}

output "web_app_name" {
  value = module.webapp.web_app_name
}

output "web_app_url" {
  value = module.webapp.web_app_url
}

output "app_insights_name" {
  value = module.monitoring.app_insights_name
}

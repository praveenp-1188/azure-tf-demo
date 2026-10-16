# Reusable monitoring module:
# Log Analytics workspace + workspace-based Application Insights + email Action Group.
# Free-tier friendly: first 5 GB/month of ingestion is free, and a daily cap stops surprises.

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30 # 30 days retention is included at no extra cost
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                 = "appi-${var.name_prefix}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  workspace_id         = azurerm_log_analytics_workspace.this.id
  application_type     = "web"
  daily_data_cap_in_gb = var.daily_quota_gb
  tags                 = var.tags
}

# Action groups and email notifications are free (up to 1,000 emails/month).
resource "azurerm_monitor_action_group" "email" {
  name                = "ag-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace(var.name_prefix, "-", ""), 0, 12)
  tags                = var.tags

  email_receiver {
    name                    = "owner"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

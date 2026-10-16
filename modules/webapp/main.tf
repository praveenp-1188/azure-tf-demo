# Reusable web app module: Linux App Service on the F1 (Free) plan,
# wired to Application Insights and Log Analytics, with an optional 5xx alert.

resource "azurerm_service_plan" "this" {
  name                = "asp-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "F1" # Free tier: 60 CPU min/day, 1 GB RAM, no always-on
  tags                = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = "app-${var.name_prefix}-${var.unique_suffix}" # must be globally unique
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true
  tags                = var.tags

  site_config {
    always_on = false # not available on F1

    application_stack {
      node_version = "20-lts"
    }
  }

  app_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING      = var.app_insights_connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~3" # codeless auto-instrumentation
  }

  identity {
    type = "SystemAssigned"
  }
}

# Send platform logs/metrics to Log Analytics (counts toward the free 5 GB/month).
resource "azurerm_monitor_diagnostic_setting" "webapp" {
  name                       = "diag-to-law"
  target_resource_id         = azurerm_linux_web_app.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceConsoleLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Metric alert on server errors. Note: metric alert rules are billed per
# monitored time series (roughly $0.10/month), so this is opt-in.
resource "azurerm_monitor_metric_alert" "http5xx" {
  count               = var.enable_metric_alert ? 1 : 0
  name                = "alert-${var.name_prefix}-http5xx"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_linux_web_app.this.id]
  description         = "More than 5 HTTP 5xx responses in 5 minutes"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5
  }

  action {
    action_group_id = var.action_group_id
  }
}

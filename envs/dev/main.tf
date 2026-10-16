terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state in Azure Storage. Values come from backend.hcl / CI secrets.
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }
}

# Subscription and auth come from ARM_* environment variables (OIDC in CI, az login locally).
provider "azurerm" {
  features {}
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  alert_email         = var.alert_email
  tags                = local.tags
}

module "webapp" {
  source = "../../modules/webapp"

  name_prefix                    = local.name_prefix
  unique_suffix                  = random_string.suffix.result
  location                       = azurerm_resource_group.this.location
  resource_group_name            = azurerm_resource_group.this.name
  app_insights_connection_string = module.monitoring.app_insights_connection_string
  log_analytics_workspace_id     = module.monitoring.log_analytics_workspace_id
  action_group_id                = module.monitoring.action_group_id
  enable_metric_alert            = var.enable_metric_alert
  tags                           = local.tags
}

# Cost guardrail: budgets are free. Emails you at 50% and 100% of a tiny monthly budget.
resource "azurerm_consumption_budget_resource_group" "this" {
  name              = "budget-${local.name_prefix}"
  resource_group_id = azurerm_resource_group.this.id
  amount            = var.monthly_budget
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    contact_groups = [module.monitoring.action_group_id]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }

  lifecycle {
    ignore_changes = [time_period] # start_date must not move after creation
  }
}

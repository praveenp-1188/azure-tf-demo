variable "name_prefix" {
  type = string
}

variable "unique_suffix" {
  description = "Short random suffix so the web app hostname is globally unique"
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "app_insights_connection_string" {
  type      = string
  sensitive = true
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "action_group_id" {
  type = string
}

variable "enable_metric_alert" {
  description = "Create the HTTP 5xx metric alert (small monthly charge)"
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}

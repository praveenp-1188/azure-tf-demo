variable "project" {
  type    = string
  default = "demo"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "location" {
  type    = string
  default = "northeurope"
}

variable "alert_email" {
  description = "Where alerts and budget notifications go"
  type        = string
}

variable "enable_metric_alert" {
  type    = bool
  default = false
}

variable "monthly_budget" {
  description = "Monthly budget in your billing currency"
  type        = number
  default     = 5
}

variable "budget_start_date" {
  description = "First day of a month, RFC3339, e.g. 2026-10-01T00:00:00Z"
  type        = string
  default     = "2026-10-01T00:00:00Z"
}

variable "name_prefix" {
  description = "Prefix used in resource names, e.g. demo-dev"
  type        = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "alert_email" {
  description = "Email address that receives alerts"
  type        = string
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. 0.1 GB/day keeps you well inside the 5 GB/month free grant."
  type        = number
  default     = 0.1
}

variable "tags" {
  type    = map(string)
  default = {}
}

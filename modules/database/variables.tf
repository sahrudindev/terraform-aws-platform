variable "project" { type = string }
variable "environment" { type = string }

variable "vpc_id" {
  type        = string
  description = "VPC tempat database dibuat"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnet privat untuk DB subnet group"
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security group yang boleh konek ke DB (mis. SG aplikasi). Kosong = belum ada yang boleh."
  default     = []
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "port" {
  type    = number
  default = 5432
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Batas auto-scaling storage"
  default     = 50
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "username" {
  type    = string
  default = "appadmin"
}

variable "multi_az" {
  type        = bool
  description = "Run a standby in a second AZ. Safe by default; dev opts out explicitly."
  default     = true
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Block accidental deletion. Safe by default; dev opts out explicitly."
  default     = true
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Discard the instance without a final snapshot. Safe by default; dev opts out explicitly."
  default     = false
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Performance Insights is free for 7 days of retention on supported classes."
  default     = true
}

variable "monitoring_interval" {
  type        = number
  description = "Enhanced monitoring granularity in seconds. 0 disables it."
  default     = 60
}

variable "enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "Engine log types shipped to CloudWatch Logs."
  default     = ["postgresql", "upgrade"]
}

variable "iam_database_authentication_enabled" {
  type        = bool
  description = "Allow IAM-issued short-lived tokens instead of passwords for application logins."
  default     = true
}

variable "auto_minor_version_upgrade" {
  type        = bool
  description = "Apply minor engine patches during the maintenance window."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "CMK for storage and Performance Insights. Null creates one in this module."
  default     = null
}

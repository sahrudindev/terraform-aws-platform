variable "project" {
  type        = string
  description = "Nama proyek"
}

variable "environment" {
  type        = string
  description = "Nama environment (dev/prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block untuk VPC"
  default     = "10.10.0.0/16"
}

variable "az_count" {
  type        = number
  description = "Jumlah Availability Zone yang dipakai"
  default     = 2
}

variable "single_nat_gateway" {
  type        = bool
  description = "true = 1 NAT (hemat, untuk dev). false = 1 NAT per-AZ (HA, untuk prod)"
  default     = true
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Buat NAT Gateway? Matikan untuk hemat saat tidak ada workload di subnet privat"
  default     = true
}

variable "enable_flow_logs" {
  type        = bool
  description = "Ship VPC Flow Logs to CloudWatch Logs. Required for any network forensics."
  default     = true
}

variable "flow_log_retention_days" {
  type        = number
  description = "Retention for the flow log group. 30 days balances cost against usefulness."
  default     = 30
}

variable "kms_key_arn" {
  type        = string
  description = "Customer-managed KMS key used to encrypt log data. Null falls back to AWS-owned keys."
  default     = null
}

variable "map_public_ip_on_launch" {
  type        = bool
  description = "Auto-assign public IPs in public subnets. Not needed for ALB or NAT, which bring their own addressing."
  default     = false
}

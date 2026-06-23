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

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
  default = "16.4"
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
  description = "true untuk prod (high availability)"
  default     = false
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "true di dev (boleh hilang). false di prod."
  default     = true
}

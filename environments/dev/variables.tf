# --- Identitas environment --------------------------------------------------
variable "project" {
  type    = string
  default = "cloudops"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16" # dev memakai rentang 10.10.x
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Buat NAT Gateway (~$32/bln). Nyalakan hanya saat ada workload di subnet privat."
  default     = false
}

# --- Feature flags: nyalakan workload satu per satu (hemat & aman) ----------
variable "enable_database" {
  type    = bool
  default = false
}
variable "enable_web_app" {
  type    = bool
  default = false
}
variable "enable_serverless" {
  type    = bool
  default = false
}
variable "enable_eks" {
  type    = bool
  default = false
}
variable "enable_data_lake" {
  type    = bool
  default = false
}

# --- Ukuran resource (dev = kecil) ------------------------------------------
variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

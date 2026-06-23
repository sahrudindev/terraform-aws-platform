# --- Identitas environment --------------------------------------------------
variable "project" {
  type    = string
  default = "cloudops"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16" # prod memakai rentang 10.20.x (beda dari dev)
}

# --- Feature flags ----------------------------------------------------------
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

# --- Ukuran resource (prod = lebih besar) -----------------------------------
variable "db_instance_class" {
  type    = string
  default = "db.t4g.small"
}

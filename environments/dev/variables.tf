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

variable "az_count" {
  type        = number
  description = "How many availability zones to spread subnets across. Two is the minimum for an ALB; three costs an extra NAT in prod."
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4. An ALB requires at least two AZs, and the /16 CIDR maths stops working past four."
  }
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
# The one workload left on in dev. Lambda and API Gateway sit inside the free
# tier at portfolio traffic, so this can stay up permanently and give the README
# a URL a reader can actually click. Everything below it still costs money while
# idle and stays off.
variable "enable_serverless" {
  type    = bool
  default = true
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

variable "git_commit" {
  type        = string
  description = "Commit this environment was deployed from. CI passes TF_VAR_git_commit; locally it stays \"local\"."
  default     = "local"
}

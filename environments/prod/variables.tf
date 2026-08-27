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
  default = "10.20.0.0/16" # prod memakai rentang 10.20.x (beda dari dev)
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Create NAT Gateways (~$32/month each). Required for private-subnet workloads."
  default     = true
}

variable "single_nat_gateway" {
  type        = bool
  description = "true = one shared NAT (cheap). false = one NAT per AZ (highly available)."
  default     = false
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

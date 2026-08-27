variable "project" { type = string }
variable "environment" { type = string }

variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }

variable "container_image" {
  type        = string
  description = "Image container yang dijalankan (default: nginx untuk demo)"
  default     = "public.ecr.aws/nginx/nginx:latest"
}

variable "container_port" {
  type    = number
  default = 80
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "cpu" {
  type        = number
  description = "CPU unit Fargate (256 = 0.25 vCPU)"
  default     = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "enable_deletion_protection" {
  type        = bool
  description = "Block accidental deletion of the load balancer. Should be true in prod."
  default     = false
}

variable "enable_access_logs" {
  type        = bool
  description = "Write ALB access logs to a dedicated S3 bucket."
  default     = true
}

variable "access_logs_retention_days" {
  type        = number
  description = "How long ALB access logs are kept."
  default     = 90
}

variable "min_capacity" {
  type        = number
  description = "Lower bound for service auto scaling."
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Upper bound for service auto scaling. Also caps runaway cost."
  default     = 4
}

variable "target_cpu_utilization" {
  type        = number
  description = "Average CPU percentage the scaler aims to hold."
  default     = 70
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC, used to scope ALB egress to the private subnets."
}

variable "kms_key_arn" {
  type        = string
  description = "CMK used to encrypt the task log group."
  default     = null
}

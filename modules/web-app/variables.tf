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

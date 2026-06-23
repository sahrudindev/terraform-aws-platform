variable "project" { type = string }
variable "environment" { type = string }

variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }

variable "kubernetes_version" {
  type    = string
  default = "1.31"
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "desired_size" {
  type    = number
  default = 2
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "endpoint_public_access" {
  type        = bool
  description = "Akses API server dari internet (mudah untuk belajar; matikan di prod)"
  default     = true
}

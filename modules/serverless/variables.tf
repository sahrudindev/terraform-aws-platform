variable "project" { type = string }
variable "environment" { type = string }

variable "runtime" {
  type    = string
  default = "python3.12"
}

variable "handler" {
  type        = string
  description = "Format: <namafile>.<namafungsi>"
  default     = "handler.handler"
}

variable "timeout" {
  type    = number
  default = 10
}

variable "memory_size" {
  type    = number
  default = 128
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 14
}

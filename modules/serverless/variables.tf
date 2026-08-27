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

variable "tracing_mode" {
  type        = string
  description = "X-Ray tracing mode: Active traces every invocation sampled by X-Ray."
  default     = "Active"
}

variable "reserved_concurrent_executions" {
  type        = number
  description = "Cap on concurrent executions. -1 means unreserved. A cap stops a runaway loop from consuming the account-wide limit."
  default     = 10
}

variable "kms_key_arn" {
  type        = string
  description = "CMK used to encrypt the log group and the function's environment variables."
  default     = null
}

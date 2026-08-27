variable "project" { type = string }
variable "environment" { type = string }

variable "description" {
  type        = string
  description = "What this key protects. Shows up in the console and in CloudTrail."
  default     = "Shared encryption key"
}

variable "service_principals" {
  type        = list(string)
  description = "AWS service principals allowed to use the key, e.g. logs.ap-southeast-1.amazonaws.com."
  default     = []
}

variable "deletion_window_in_days" {
  type        = number
  description = "Grace period before a scheduled key deletion becomes irreversible."
  default     = 30
}

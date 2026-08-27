variable "project" { type = string }
variable "environment" { type = string }

variable "force_destroy" {
  type        = bool
  description = "Izinkan hapus bucket walau masih berisi data (true di dev)"
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "Existing CMK to encrypt the buckets with. Null creates one inside this module."
  default     = null
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "How long superseded object versions are kept before deletion."
  default     = 90
}

variable "raw_transition_to_ia_days" {
  type        = number
  description = "Age at which raw objects move to Standard-IA. Raw data is written once and read rarely."
  default     = 30
}

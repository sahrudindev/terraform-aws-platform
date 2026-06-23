variable "project" { type = string }
variable "environment" { type = string }

variable "force_destroy" {
  type        = bool
  description = "Izinkan hapus bucket walau masih berisi data (true di dev)"
  default     = false
}

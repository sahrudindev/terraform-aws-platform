variable "project" {
  description = "Nama proyek, dipakai sebagai prefix penamaan resource"
  type        = string
  default     = "cloudops"
}

variable "region" {
  description = "Region AWS utama"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Nama proyek"
  type        = string
  default     = "cloudops"
}

variable "monthly_budget_usd" {
  description = "Batas budget bulanan dalam USD"
  type        = number
  default     = 20
}

variable "alert_emails" {
  description = "Daftar email penerima peringatan biaya"
  type        = list(string)
}

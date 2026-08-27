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

# --- GitHub Actions OIDC ----------------------------------------------------
variable "github_owner" {
  description = "GitHub user or organisation that owns the repository"
  type        = string
}

variable "github_repo" {
  description = "Repository name that is allowed to assume the CI roles"
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket holding Terraform state; the CI roles need access to it"
  type        = string
}

variable "budget_tag_filter" {
  description = "Only count spend tagged Project=<this>. Null makes the budget account-wide, which is wrong in any account that hosts more than this repository."
  type        = string
  default     = "cloudops"
}

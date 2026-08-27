# Nilai-nilai ini WAJIB disalin ke environments/*/backend.tf dan global/backend.tf
output "state_bucket" {
  description = "Bucket name. Put this in each stack's backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "Region backend"
  value       = var.region
}

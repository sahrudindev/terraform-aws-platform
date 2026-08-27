# Nilai-nilai ini WAJIB disalin ke environments/*/backend.tf dan global/backend.tf
output "state_bucket" {
  description = "Bucket name. Put this in each stack's backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "Region backend"
  value       = var.region
}

output "state_kms_key_arn" {
  description = "Key encrypting state. Set as state_kms_key_arn in global/terraform.tfvars so the CI roles can read state."
  value       = aws_kms_key.state.arn
}

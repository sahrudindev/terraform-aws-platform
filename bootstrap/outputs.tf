# Nilai-nilai ini WAJIB disalin ke environments/*/backend.tf dan global/backend.tf
output "state_bucket" {
  description = "Nama S3 bucket untuk menyimpan state (isi ke backend.tf -> bucket)"
  value       = aws_s3_bucket.state.id
}

output "lock_table" {
  description = "Nama DynamoDB table untuk lock (isi ke backend.tf -> dynamodb_table)"
  value       = aws_dynamodb_table.lock.name
}

output "region" {
  description = "Region backend"
  value       = var.region
}

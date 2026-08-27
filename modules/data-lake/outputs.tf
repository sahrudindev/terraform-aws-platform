output "raw_bucket" {
  value = aws_s3_bucket.this["raw"].bucket
}

output "processed_bucket" {
  value = aws_s3_bucket.this["processed"].bucket
}

output "athena_results_bucket" {
  value = aws_s3_bucket.this["athena_results"].bucket
}

output "glue_database" {
  value = aws_glue_catalog_database.this.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.this.name
}

output "kms_key_arn" {
  description = "Key encrypting the lake. Grant consumers kms:Decrypt on this."
  value       = local.kms_key_arn
}

output "key_arn" {
  description = "Pass this to any resource that accepts a kms_key_arn"
  value       = aws_kms_key.this.arn
}

output "key_id" {
  value = aws_kms_key.this.key_id
}

output "alias" {
  value = aws_kms_alias.this.name
}

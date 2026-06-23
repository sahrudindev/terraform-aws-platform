output "endpoint" {
  description = "Endpoint koneksi database (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "Host database"
  value       = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "security_group_id" {
  value = aws_security_group.db.id
}

output "master_secret_arn" {
  description = "ARN secret di Secrets Manager berisi kredensial DB"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "vpc_id" {
  description = "ID dari VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "ID subnet publik"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "ID subnet privat"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  value = local.azs
}

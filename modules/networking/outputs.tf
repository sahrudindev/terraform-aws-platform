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

output "flow_log_group_name" {
  description = "CloudWatch log group receiving VPC flow logs, if enabled"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow[0].name : null
}

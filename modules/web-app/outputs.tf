output "alb_dns_name" {
  description = "URL aplikasi (buka di browser)"
  value       = "http://${aws_lb.this.dns_name}"
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "service_security_group_id" {
  description = "SG service ECS — berikan ke module database agar app boleh konek DB"
  value       = aws_security_group.service.id
}

output "access_logs_bucket" {
  description = "Bucket receiving ALB access logs, if enabled"
  value       = var.enable_access_logs ? aws_s3_bucket.logs[0].bucket : null
}

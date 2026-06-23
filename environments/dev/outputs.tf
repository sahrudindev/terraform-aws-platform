output "vpc_id" {
  value = module.networking.vpc_id
}

output "web_app_url" {
  description = "URL aplikasi web (jika diaktifkan)"
  value       = var.enable_web_app ? module.web_app[0].alb_dns_name : "tidak aktif"
}

output "api_endpoint" {
  description = "Endpoint serverless API (jika diaktifkan)"
  value       = var.enable_serverless ? module.serverless[0].api_endpoint : "tidak aktif"
}

output "database_endpoint" {
  description = "Endpoint database (jika diaktifkan)"
  value       = var.enable_database ? module.database[0].endpoint : "tidak aktif"
}

output "eks_cluster" {
  value = var.enable_eks ? module.eks[0].cluster_name : "tidak aktif"
}

output "data_lake_raw_bucket" {
  value = var.enable_data_lake ? module.data_lake[0].raw_bucket : "tidak aktif"
}

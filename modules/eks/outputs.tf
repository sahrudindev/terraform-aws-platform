output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_data" {
  description = "Certificate authority (base64) untuk kubeconfig"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "kubeconfig_command" {
  description = "Jalankan ini untuk konek kubectl ke cluster"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region <region>"
}

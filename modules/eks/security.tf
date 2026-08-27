# ============================================================================
# Envelope encryption, control plane logging, and IRSA.
# ============================================================================

# Kubernetes Secrets are only base64 in etcd by default. This wraps them with a
# customer-managed key so a snapshot of etcd is not a snapshot of every secret.
resource "aws_kms_key" "this" {
  description             = "Envelope encryption for ${local.name}-eks secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = { Name = "${local.name}-eks" }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name}-eks"
  target_key_id = aws_kms_key.this.key_id
}

# The cluster writes here as soon as logging is enabled; creating it up front
# means retention and encryption are ours to set rather than defaulted.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.name}-eks/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = { Name = "${local.name}-eks-logs" }
}

# --- IRSA -------------------------------------------------------------------
#
# Lets a Kubernetes service account assume an IAM role directly, so pods stop
# borrowing the node role and inheriting every permission it holds.

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = { Name = "${local.name}-eks-irsa" }
}

# --- Managed addons ---------------------------------------------------------

resource "aws_eks_addon" "this" {
  for_each = var.cluster_addons

  cluster_name  = aws_eks_cluster.this.name
  addon_name    = each.key
  addon_version = each.value != "" ? each.value : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}

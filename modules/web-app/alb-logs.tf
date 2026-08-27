# ============================================================================
# ALB access logs.
#
# Without these there is no record of who requested what, which makes both
# abuse investigation and latency debugging impossible after the fact.
# ============================================================================

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_144:Cross-region replication triples storage cost. Everything here is either reproducible from source or already versioned; losing a region is not the failure mode this project is defending against.
  #checkov:skip=CKV_AWS_18:Server access logging needs a second bucket per bucket, which then needs its own logging bucket. CloudTrail data events cover the same ground without the recursion.
  #checkov:skip=CKV2_AWS_62:Event notifications are an integration mechanism, not a security control. Nothing consumes these buckets asynchronously yet.
  #checkov:skip=CKV_AWS_145:ALB log delivery does not support customer-managed KMS keys. SSE-S3 is the only option AWS accepts here.
  #checkov:skip=CKV2_AWS_6:A public access block is configured below. The resource is behind count, which the graph does not resolve.
  #checkov:skip=CKV_AWS_21:Versioning is configured below. Same count-resolution limitation.
  #checkov:skip=CKV2_AWS_61:A lifecycle configuration is defined below. Same count-resolution limitation.
  count = var.enable_access_logs ? 1 : 0

  bucket        = "${local.name}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = { Name = "${local.name}-alb-logs" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  rule {
    apply_server_side_encryption_by_default {
      # ALB log delivery does not support customer-managed KMS keys.
      #checkov:skip=CKV_AWS_145:ALB access log delivery only supports SSE-S3.
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket = aws_s3_bucket.logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket     = aws_s3_bucket.logs[0].id
  depends_on = [aws_s3_bucket_versioning.logs]

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.access_logs_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "logs" {
  count = var.enable_access_logs ? 1 : 0

  statement {
    sid    = "AllowLoadBalancerLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs[0].arn}/*"]
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.logs[0].arn,
      "${aws_s3_bucket.logs[0].arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  count = var.enable_access_logs ? 1 : 0

  bucket     = aws_s3_bucket.logs[0].id
  policy     = data.aws_iam_policy_document.logs[0].json
  depends_on = [aws_s3_bucket_public_access_block.logs]
}

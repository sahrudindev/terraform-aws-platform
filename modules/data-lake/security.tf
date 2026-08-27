# ============================================================================
# Encryption, versioning, lifecycle and transport security for the lake.
# ============================================================================

locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
}

data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_356:kms:* on "*" inside a key policy means "this key", not every key. AWS requires this root statement or the key becomes ungrantable through IAM.
  #checkov:skip=CKV_AWS_109:Same statement. A key policy is scoped to the key it is attached to; the resource wildcard has no wider meaning here.
  #checkov:skip=CKV_AWS_111:Same statement.
  count = var.kms_key_arn == null ? 1 : 0

  # A key with no root statement cannot be granted through IAM at all, which
  # locks the account out of its own key.
  statement {
    sid       = "EnableIAMPolicies"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid     = "AllowS3AndAthena"
    actions = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]

    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com", "athena.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  policy                  = data.aws_iam_policy_document.kms[0].json
  description             = "Encrypts the ${local.name} data lake buckets"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = { Name = "${local.name}-datalake" }
}

resource "aws_kms_alias" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${local.name}-datalake"
  target_key_id = aws_kms_key.this[0].key_id
}

# Recover from an overwrite or a bad transform job.
resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning without expiry grows without bound, so pair the two.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = local.buckets

  bucket     = aws_s3_bucket.this[each.key].id
  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Raw data is append-only and cold almost immediately.
  dynamic "rule" {
    for_each = each.key == "raw" ? [1] : []

    content {
      id     = "raw-to-infrequent-access"
      status = "Enabled"

      filter {}

      transition {
        days          = var.raw_transition_to_ia_days
        storage_class = "STANDARD_IA"
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
    }
  }

  # Athena results are disposable once read.
  dynamic "rule" {
    for_each = each.key == "athena_results" ? [1] : []

    content {
      id     = "expire-query-results"
      status = "Enabled"

      filter {}

      expiration {
        days = 30
      }

      abort_incomplete_multipart_upload {
        days_after_initiation = 7
      }
    }
  }
}

# Reject anything that arrives over plaintext HTTP.
data "aws_iam_policy_document" "tls_only" {
  for_each = local.buckets

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this[each.key].arn,
      "${aws_s3_bucket.this[each.key].arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tls_only" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id
  policy = data.aws_iam_policy_document.tls_only[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

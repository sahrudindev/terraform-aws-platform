locals {
  kms_key_arn = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.this[0].arn
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_356:kms:* on "*" inside a key policy means "this key", not every key. AWS requires this root statement or the key becomes ungrantable through IAM.
  #checkov:skip=CKV_AWS_109:Same statement. A key policy is scoped to the key it is attached to; the resource wildcard has no wider meaning here.
  #checkov:skip=CKV_AWS_111:Same statement.
  count = var.kms_key_arn == null ? 1 : 0

  # Without an explicit policy a key is unusable by anything but its creator,
  # so the account root statement is what makes IAM grants work at all.
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
    sid       = "AllowRDSService"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "Encrypts ${local.name} database storage and Performance Insights"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms[0].json

  tags = { Name = "${local.name}-db" }
}

resource "aws_kms_alias" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${local.name}-db"
  target_key_id = aws_kms_key.this[0].key_id
}

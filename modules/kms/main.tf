# ============================================================================
# One customer-managed key per environment.
#
# A CMK, unlike an AWS-owned key, has an auditable policy, rotates on a
# schedule we control, and can be revoked - which is what makes "encrypted at
# rest" mean something during an incident.
# ============================================================================

locals {
  name = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "this" {
  #checkov:skip=CKV_AWS_356:kms:* on "*" inside a key policy means "this key", not every key. AWS requires this root statement or the key becomes ungrantable through IAM.
  #checkov:skip=CKV_AWS_109:Same statement. A key policy is scoped to the key it is attached to; the resource wildcard has no wider meaning here.
  #checkov:skip=CKV_AWS_111:Same statement.
  # A key with no root statement cannot be granted to anyone via IAM, which
  # locks the account out of its own key.
  statement {
    sid       = "EnableIAMPolicies"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(var.service_principals) > 0 ? [1] : []

    content {
      sid    = "AllowAwsServices"
      effect = "Allow"

      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
        "kms:CreateGrant",
      ]

      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = var.service_principals
      }

      # Only for resources in this account, so a confused-deputy grant from
      # another account cannot use the key.
      condition {
        test     = "StringEquals"
        variable = "aws:SourceAccount"
        values   = [data.aws_caller_identity.current.account_id]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "${var.description} (${local.name})"
  policy                  = data.aws_iam_policy_document.this.json
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days

  tags = { Name = local.name }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.this.key_id
}

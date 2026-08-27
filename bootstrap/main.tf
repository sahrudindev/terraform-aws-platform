# ============================================================================
# BOOTSTRAP - the S3 bucket every other stack keeps its state in.
#
# Run once, with `make bootstrap`. The bucket is created with local state, then
# this stack's own state is migrated into the bucket it just created. Circular,
# and deliberate: afterwards no Terraform state exists on any workstation.
#
# See docs/adr/0005-bootstrapping-the-state-backend.md.
# ============================================================================

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "Terraform"
      Component = "tf-state-backend"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  # Nama bucket dibuat unik secara global dengan menyertakan Account ID
  bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# --- KMS key for the state bucket ------------------------------------------
#
# The key and the bucket are created in the same apply, so there is no ordering
# problem: nothing needs to read state until after both exist.
#
# The consequence to understand is that losing this key makes every state file
# unreadable. deletion_window_in_days gives 30 days to notice, and the key
# policy below keeps the account root able to recover it.
data "aws_iam_policy_document" "state_key" {
  #checkov:skip=CKV_AWS_356:kms:* on "*" inside a key policy scopes to this key alone. AWS requires the root statement or the key cannot be granted through IAM.
  #checkov:skip=CKV_AWS_109:Same statement.
  #checkov:skip=CKV_AWS_111:Same statement.
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
    sid       = "AllowS3ToUseTheKey"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_kms_key" "state" {
  description             = "Encrypts Terraform state for ${var.project}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.state_key.json

  tags = { Name = "${var.project}-tfstate" }
}

resource "aws_kms_alias" "state" {
  name          = "alias/${var.project}-tfstate"
  target_key_id = aws_kms_key.state.key_id
}

# --- S3 bucket: tempat menyimpan file terraform.tfstate -------------------
resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_144:Cross-region replication triples storage cost. Everything here is either reproducible from source or already versioned; losing a region is not the failure mode this project is defending against.
  #checkov:skip=CKV_AWS_18:Server access logging needs a second bucket per bucket, which then needs its own logging bucket. CloudTrail data events cover the same ground without the recursion.
  #checkov:skip=CKV2_AWS_62:Event notifications are an integration mechanism, not a security control. Nothing consumes these buckets asynchronously yet.
  bucket = local.bucket_name

  # Destroying this bucket destroys the record of every other stack. Removing
  # it is a deliberate, manual act, not something a stray `terraform destroy`
  # can do.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning: simpan riwayat state agar bisa rollback jika rusak
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enkripsi otomatis untuk semua object
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    # State files are small and written often; the bucket key collapses what
    # would otherwise be one KMS request per write.
    bucket_key_enabled = true
  }
}

# Tutup total akses publik (state itu rahasia)
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Keep old state versions from accumulating forever ---------------------
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket     = aws_s3_bucket.state.id
  depends_on = [aws_s3_bucket_versioning.state]

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    # 90 days of history is far more than any rollback has ever needed, and
    # state files are small enough that this is about tidiness, not cost.
    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Refuse plaintext access to the state bucket ---------------------------
data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket     = aws_s3_bucket.state.id
  policy     = data.aws_iam_policy_document.state_tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.state]
}

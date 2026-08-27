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

# --- S3 bucket: tempat menyimpan file terraform.tfstate -------------------
resource "aws_s3_bucket" "state" {
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
      sse_algorithm = "AES256"
    }
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

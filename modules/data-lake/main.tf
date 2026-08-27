# ============================================================================
# MODULE DATA-LAKE — S3 (raw/processed/results) + Glue Catalog + Athena
# ============================================================================

locals {
  name = "${var.project}-${var.environment}"
}

data "aws_caller_identity" "current" {}

locals {
  buckets = {
    raw            = "${local.name}-datalake-raw-${data.aws_caller_identity.current.account_id}"
    processed      = "${local.name}-datalake-processed-${data.aws_caller_identity.current.account_id}"
    athena_results = "${local.name}-athena-results-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_bucket" "this" {
  #checkov:skip=CKV_AWS_144:Cross-region replication triples storage cost. Everything here is either reproducible from source or already versioned; losing a region is not the failure mode this project is defending against.
  #checkov:skip=CKV_AWS_18:Server access logging needs a second bucket per bucket, which then needs its own logging bucket. CloudTrail data events cover the same ground without the recursion.
  #checkov:skip=CKV2_AWS_62:Event notifications are an integration mechanism, not a security control. Nothing consumes these buckets asynchronously yet.
  for_each      = local.buckets
  bucket        = each.value
  force_destroy = var.force_destroy
  tags = {
    Name    = each.value
    Purpose = each.key
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = local.buckets
  bucket                  = aws_s3_bucket.this[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_key_arn
    }
    # Cuts KMS request cost dramatically for many small objects.
    bucket_key_enabled = true
  }
}

# --- Glue Data Catalog (skema/tabel untuk query) ---------------------------
resource "aws_glue_catalog_database" "this" {
  name = replace("${local.name}_datalake", "-", "_")
}

# --- Athena workgroup (untuk menjalankan query SQL) ------------------------
resource "aws_athena_workgroup" "this" {
  name = "${local.name}-wg"

  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.this["athena_results"].bucket}/output/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = local.kms_key_arn
      }
    }
  }

  force_destroy = var.force_destroy
}

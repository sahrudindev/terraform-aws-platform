# ============================================================================
# BOOTSTRAP — membuat backend untuk menyimpan Terraform state
# Dijalankan SEKALI di awal. State bootstrap sendiri disimpan lokal.
# ============================================================================

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
  table_name  = "${var.project}-tfstate-lock"
}

# --- S3 bucket: tempat menyimpan file terraform.tfstate -------------------
resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name
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

# --- DynamoDB: mengunci state agar tidak bentrok saat apply bersamaan ------
resource "aws_dynamodb_table" "lock" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST" # bayar per pakai, praktis nyaris gratis
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

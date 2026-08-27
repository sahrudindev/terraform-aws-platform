# ============================================================================
# MODULE DATABASE — RDS (PostgreSQL) di subnet privat
# Password master dikelola otomatis oleh AWS Secrets Manager (lebih aman).
# ============================================================================

locals {
  name = "${var.project}-${var.environment}"
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.name}-db-subnet" }
}

resource "aws_security_group" "db" {
  name_prefix = "${local.name}-db-"
  description = "Security group untuk RDS ${local.name}"
  vpc_id      = var.vpc_id

  # RDS is a managed service; the instance initiates nothing outbound that we
  # control, so the group is closed rather than left wide open.
  egress {
    description = "No outbound access required by a managed RDS instance"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["127.0.0.1/32"]
  }

  lifecycle { create_before_destroy = true }
  tags = { Name = "${local.name}-db-sg" }
}

# Ingress hanya dibuat untuk SG yang diizinkan (nol rule jika daftar kosong)
resource "aws_vpc_security_group_ingress_rule" "db" {
  for_each = toset(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.db.id
  referenced_security_group_id = each.value
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  description                  = "DB access from ${each.value}"
}

resource "aws_db_instance" "this" {
  identifier = "${local.name}-db"
  engine     = var.engine
  # Major version only. Pinning the patch level turns every AWS-managed
  # minor upgrade into spurious drift on the next plan.
  engine_version             = var.engine_version
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  instance_class             = var.instance_class
  port                       = var.port

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = local.kms_key_arn

  db_name  = var.db_name
  username = var.username
  # Password dibuat & disimpan otomatis di Secrets Manager — tidak ada plaintext
  manage_master_user_password = true

  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  multi_az                = var.multi_az
  publicly_accessible     = false
  backup_retention_period = var.backup_retention_period

  performance_insights_enabled    = var.performance_insights_enabled
  performance_insights_kms_key_id = var.performance_insights_enabled ? local.kms_key_arn : null
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.monitoring[0].arn : null
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Applications can authenticate with short-lived IAM tokens rather than a
  # shared password.
  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  copy_tags_to_snapshot     = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name}-db-final"
  apply_immediately         = true

  tags = { Name = "${local.name}-db" }

  # Guardrails that cannot be forgotten at the call site.
  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.deletion_protection
      error_message = "deletion_protection must be true in prod."
    }

    precondition {
      condition     = var.environment != "prod" || !var.skip_final_snapshot
      error_message = "prod must take a final snapshot before the instance is destroyed."
    }

    precondition {
      condition     = var.environment != "prod" || var.backup_retention_period >= 7
      error_message = "prod requires at least 7 days of automated backups."
    }
  }
}

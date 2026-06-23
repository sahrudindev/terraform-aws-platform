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

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  identifier     = "${local.name}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  port           = var.port

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username
  # Password dibuat & disimpan otomatis di Secrets Manager — tidak ada plaintext
  manage_master_user_password = true

  db_subnet_group_name      = aws_db_subnet_group.this.name
  vpc_security_group_ids    = [aws_security_group.db.id]
  multi_az                  = var.multi_az
  publicly_accessible       = false
  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name}-db-final"
  apply_immediately         = true

  tags = { Name = "${local.name}-db" }
}

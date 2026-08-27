# ============================================================================
# ENVIRONMENT: PROD — setting produksi: HA, multi-AZ, proteksi penghapusan.
# ============================================================================

module "kms" {
  source = "../../modules/kms"

  project     = var.project
  environment = var.environment
  description = "Shared key for logs, storage and secrets"

  service_principals = [
    "logs.${var.region}.amazonaws.com",
    "s3.amazonaws.com",
  ]
}

module "networking" {
  source = "../../modules/networking"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  az_count           = 2
  single_nat_gateway = var.single_nat_gateway
  enable_nat_gateway = var.enable_nat_gateway
  kms_key_arn        = module.kms.key_arn
}

module "web_app" {
  source = "../../modules/web-app"
  count  = var.enable_web_app ? 1 : 0

  project            = var.project
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  vpc_cidr           = module.networking.vpc_cidr
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  desired_count      = 2 # prod: minimal 2 untuk redundansi
  cpu                = 512
  memory             = 1024

  enable_deletion_protection = true
  min_capacity               = 2
  max_capacity               = 6
  kms_key_arn                = module.kms.key_arn
}

module "database" {
  source = "../../modules/database"
  count  = var.enable_database ? 1 : 0

  project             = var.project
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  instance_class      = var.db_instance_class
  multi_az            = true  # prod: high availability
  deletion_protection = true  # prod: cegah terhapus tak sengaja
  skip_final_snapshot = false # prod: selalu snapshot sebelum hapus

  allowed_security_group_ids = var.enable_web_app ? [module.web_app[0].service_security_group_id] : []
  kms_key_arn                = module.kms.key_arn
}

module "serverless" {
  source = "../../modules/serverless"
  count  = var.enable_serverless ? 1 : 0

  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms.key_arn
}

module "eks" {
  source = "../../modules/eks"
  count  = var.enable_eks ? 1 : 0

  project                = var.project
  environment            = var.environment
  private_subnet_ids     = module.networking.private_subnet_ids
  public_subnet_ids      = module.networking.public_subnet_ids
  desired_size           = 2
  min_size               = 2
  max_size               = 4
  endpoint_public_access = false # prod: API server tidak terbuka ke internet
  kms_key_arn            = module.kms.key_arn
}

module "data_lake" {
  source = "../../modules/data-lake"
  count  = var.enable_data_lake ? 1 : 0

  project       = var.project
  environment   = var.environment
  force_destroy = false # prod: lindungi data
  kms_key_arn   = module.kms.key_arn
}

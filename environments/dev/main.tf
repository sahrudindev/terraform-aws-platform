# ============================================================================
# ENVIRONMENT: DEV — merangkai modules. Workload dinyalakan via feature flag
# di terraform.tfvars. Networking selalu aktif sebagai fondasi.
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
  az_count           = var.az_count
  single_nat_gateway = true # dev: 1 NAT saja untuk hemat
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
  desired_count      = 1
  kms_key_arn        = module.kms.key_arn
}

module "database" {
  source = "../../modules/database"
  count  = var.enable_database ? 1 : 0

  project             = var.project
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  instance_class      = var.db_instance_class
  multi_az            = false
  deletion_protection = false
  skip_final_snapshot = true

  # Izinkan web-app konek ke DB jika web-app aktif
  allowed_security_group_ids = var.enable_web_app ? [module.web_app[0].service_security_group_id] : []
  kms_key_arn                = module.kms.key_arn
}

module "serverless" {
  source = "../../modules/serverless"
  count  = var.enable_serverless ? 1 : 0

  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms.key_arn

  environment_variables = {
    ENVIRONMENT = var.environment
    GIT_COMMIT  = var.git_commit
  }
}

module "eks" {
  source = "../../modules/eks"
  count  = var.enable_eks ? 1 : 0

  project            = var.project
  environment        = var.environment
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  desired_size       = 1 # dev: kecil
  min_size           = 1
  max_size           = 2
  kms_key_arn        = module.kms.key_arn
}

module "data_lake" {
  source = "../../modules/data-lake"
  count  = var.enable_data_lake ? 1 : 0

  project       = var.project
  environment   = var.environment
  force_destroy = true # dev: boleh dihapus walau ada data
  kms_key_arn   = module.kms.key_arn
}

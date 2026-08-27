# Partial backend configuration.
#
# The bucket name embeds the AWS account id, so it is supplied at init time
# instead of being committed:
#
#   terraform init -backend-config=backend.hcl
#
# Copy backend.hcl.example -> backend.hcl and fill in your account id.
terraform {
  backend "s3" {
    key          = "dev/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true # native S3 locking (Terraform >= 1.10); replaces DynamoDB
  }
}

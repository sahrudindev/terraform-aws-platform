# Enabled by `make bootstrap` after the bucket exists.
#
# The bootstrap stack stores its own state in the bucket it created. That is
# circular, and it is fine: the bucket is created first with local state, then
# that state is migrated in. What it buys is that no stack - including this one
# - depends on a state file sitting on one person's laptop.
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

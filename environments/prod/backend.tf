# Isi bucket & dynamodb_table dengan output dari folder bootstrap,
# lalu jalankan: terraform init
terraform {
  backend "s3" {
    bucket         = "cloudops-tfstate-586723123091"
    key            = "prod/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cloudops-tfstate-lock"
    encrypt        = true
  }
}

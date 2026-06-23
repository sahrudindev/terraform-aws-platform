# Isi bucket & dynamodb_table dengan output dari folder bootstrap.
# Setelah diisi, jalankan: terraform init
terraform {
  backend "s3" {
    bucket         = "cloudops-tfstate-586723123091"
    key            = "global/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "cloudops-tfstate-lock"
    encrypt        = true
  }
}

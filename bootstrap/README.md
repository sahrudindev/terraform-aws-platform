# Bootstrap — Remote State Backend

Dijalankan **sekali** untuk membuat S3 bucket + DynamoDB table tempat semua
state Terraform lain disimpan.

```bash
cd bootstrap
terraform init          # state bootstrap ini lokal (tidak apa-apa)
terraform plan
terraform apply         # ketik 'yes'

# Catat output-nya:
terraform output
#   state_bucket = "cloudops-tfstate-123456789012"
#   lock_table   = "cloudops-tfstate-lock"
```

Setelah ini, **salin** `state_bucket` dan `lock_table` ke:
- `environments/dev/backend.tf`
- `environments/prod/backend.tf`
- `global/backend.tf`

Lalu jalankan `terraform init` di masing-masing folder tersebut.

> Jangan `terraform destroy` folder ini selama backend masih dipakai.

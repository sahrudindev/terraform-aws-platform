# Terraform AWS — Infrastructure as Code

Pengelolaan penuh infrastruktur AWS via Terraform. Cetak biru lengkap ada di
**[PLANNING.md](PLANNING.md)**. Untuk **belajar** (penjelasan tiap komponen +
cara manual di Console), baca **[docs/BELAJAR.md](docs/BELAJAR.md)**.

| | |
|---|---|
| Region | `ap-southeast-1` (Singapore) |
| Environment | `dev`, `prod` (terisolasi) |
| Workload | Web App+DB, Serverless, EKS, Data Lake |
| State | S3 + DynamoDB (dibuat via `bootstrap/`) |
| Tools | Terraform v1.15.6, AWS CLI v2 — sudah terpasang di `~/.local/bin` |

## Struktur

```
bootstrap/      → buat S3+DynamoDB untuk state (jalan SEKALI)
global/         → budget & billing alarm (account-wide)
modules/        → komponen reusable
  networking/   → VPC, subnet, NAT, route table
  web-app/      → ALB + ECS Fargate
  database/     → RDS (PostgreSQL, password di Secrets Manager)
  serverless/   → Lambda + API Gateway
  eks/          → cluster Kubernetes + node group
  data-lake/    → S3 + Glue + Athena
environments/
  dev/          → rangkai modules (ukuran kecil, hemat)
  prod/         → rangkai modules (HA, multi-AZ, terproteksi)
```

## Cara Pakai — Urutan Sekali Setup

### 1. Bootstrap remote state (sekali saja)
```bash
cd bootstrap
terraform init
terraform apply          # ketik 'yes'
terraform output         # CATAT: state_bucket & lock_table
```

### 2. Isi backend di 3 file
Salin nilai `state_bucket` & `lock_table` ke bagian `GANTI_DENGAN_...` pada:
- `environments/dev/backend.tf`
- `environments/prod/backend.tf`
- `global/backend.tf`

### 3. Aktifkan guardrail biaya
```bash
cd global
terraform init          # akan memakai S3 backend
terraform apply         # buat budget + email alert
```

### 4. Bangun fondasi dev
```bash
cd environments/dev
terraform init
terraform apply          # membuat VPC/networking (workload masih off)
```

## Cara Menyalakan Workload (feature flag)

Semua workload **default mati** demi hemat. Untuk menyalakan, ubah `false → true`
di `environments/dev/terraform.tfvars`:

```hcl
enable_web_app    = true    # nyalakan web app
enable_serverless = true    # nyalakan Lambda+API
enable_database   = true
enable_eks        = true    # ⚠️ ~$73/bln, matikan jika tak dipakai
enable_data_lake  = true
```
lalu:
```bash
terraform plan      # lihat dulu apa yang akan dibuat
terraform apply     # terapkan
terraform output    # lihat URL/endpoint hasil
```

Untuk `prod`: lakukan hal sama di `environments/prod/` setelah teruji di dev.

## Perintah Harian

```bash
terraform plan       # preview perubahan (SELALU sebelum apply)
terraform apply      # terapkan
terraform destroy    # hapus semua resource environment ini (hemat di dev!)
terraform output     # lihat URL, endpoint, dsb.
terraform fmt -recursive   # rapikan format
```

## Aturan Penting
- ❌ Jangan ubah resource lewat Console AWS setelah dikelola Terraform.
- ❌ Jangan commit `*.tfstate` atau `*.tfvars` berisi rahasia (sudah di `.gitignore`).
- ✅ Selalu `terraform plan` sebelum `apply`.
- ✅ `terraform destroy` di `dev` saat selesai eksperimen (hemat NAT/EKS/RDS).
- 💡 EKS & NAT Gateway berbiaya tetap walau idle — pantau email budget Anda.

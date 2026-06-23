# 📘 Panduan Belajar — Infrastruktur AWS via Terraform

> Dokumen ini menganalisa **semua yang sudah kita kerjakan**, menjelaskannya dari
> nol, dan menunjukkan **cara membuat hal yang sama secara manual** lewat AWS
> Console — supaya Anda paham apa yang sebenarnya dilakukan Terraform di balik layar.
>
> Akun: `586723123091` · Region: `ap-southeast-1` (Singapore) · Project: `cloudops`

---

## Daftar Isi
1. [Peta Besar — Apa yang Kita Bangun](#1-peta-besar)
2. [Konsep Dasar yang Wajib Dipahami](#2-konsep-dasar)
3. [Detail Tiap Komponen (Terraform ⇄ Manual Console)](#3-detail-tiap-komponen)
   - [3.1 Toolchain di Laptop](#31-toolchain-di-laptop)
   - [3.2 Kredensial & IAM](#32-kredensial--iam)
   - [3.3 Remote State (S3 + DynamoDB)](#33-remote-state-s3--dynamodb)
   - [3.4 Budget Guardrail](#34-budget-guardrail)
   - [3.5 Jaringan / VPC](#35-jaringan--vpc)
   - [3.6 Serverless (Lambda + API Gateway)](#36-serverless-lambda--api-gateway)
   - [3.7 Data Lake (S3 + Glue + Athena)](#37-data-lake-s3--glue--athena)
4. [Terraform vs Manual — Ringkasan](#4-terraform-vs-manual)
5. [Alur Kerja & Perintah Penting](#5-alur-kerja--perintah-penting)
6. [Rincian Biaya](#6-rincian-biaya)
7. [Cheat Sheet](#7-cheat-sheet)

---

## 1. Peta Besar

Inilah seluruh yang sekarang **hidup di akun AWS Anda**, semuanya dikelola lewat Terraform:

```
AWS Account 586723123091  (Region: ap-southeast-1)
│
├── 🗄️  REMOTE STATE                                  ← fondasi Terraform
│     ├── S3   : cloudops-tfstate-586723123091         (menyimpan state)
│     └── DynamoDB : cloudops-tfstate-lock             (mengunci state)
│
├── 💰  BUDGET GUARD                                   ← pengaman biaya
│     └── cloudops-monthly-budget ($20/bln → email alert)
│
└── 🌐  VPC DEV : vpc-0f1bbfc14037b3141 (10.10.0.0/16)
      ├── 2 subnet publik  + 2 subnet privat (2 AZ)
      ├── Internet Gateway + Route Tables
      ├── ⚡ SERVERLESS
      │     ├── Lambda      : cloudops-dev-fn
      │     └── API Gateway : https://beruetroad.execute-api.ap-southeast-1.amazonaws.com
      └── 📊 DATA LAKE
            ├── S3 raw / processed / athena-results
            ├── Glue DB   : cloudops_dev_datalake (tabel: kontak)
            └── Athena WG : cloudops-dev-wg
```

**Total biaya berjalan: ~$0/bln** (semua dalam free tier / pay-per-use).

---

## 2. Konsep Dasar

### Apa itu Infrastructure as Code (IaC)?
Alih-alih meng-klik tombol di AWS Console (cara manual), kita **menulis file teks**
yang mendeskripsikan infrastruktur yang diinginkan. Terraform membaca file itu lalu
membuat/mengubah resource di AWS agar cocok.

| | Manual (Console) | Terraform (IaC) |
|---|---|---|
| Cara | Klik tombol di web | Tulis kode `.tf` |
| Ulang di env lain | Klik ulang semua, rawan beda | `terraform apply` lagi |
| Riwayat perubahan | Tidak ada | Tercatat di Git |
| Hapus rapi | Manual satu-satu | `terraform destroy` |
| Dokumentasi | Terpisah, mudah usang | Kodenya = dokumentasi |

### 3 file/konsep inti Terraform
- **`.tf`** — kode yang Anda tulis (resource yang diinginkan).
- **State** (`terraform.tfstate`) — catatan Terraform tentang resource apa yang sudah
  ia buat & ID-nya. Inilah "sumber kebenaran". Kita simpan di S3 (remote state).
- **Provider** — plugin yang tahu cara bicara ke AWS (kita pakai `hashicorp/aws ~> 5.0`).

### Siklus kerja
```
tulis kode → terraform plan (preview) → terraform apply (terapkan) → state ter-update
```

> ⚠️ **Aturan emas:** setelah resource dikelola Terraform, **jangan diubah manual di
> Console**. Kalau diubah manual, kode & kenyataan jadi beda (*drift*), dan Terraform
> bisa menimpa/merusaknya saat apply berikutnya.

---

## 3. Detail Tiap Komponen

Tiap bagian punya format sama: **Apa & Kenapa** → **Cara Terraform** → **🖱️ Cara Manual di Console**.

---

### 3.1 Toolchain di Laptop

**Apa & Kenapa:** Sebelum bisa mengelola AWS, laptop perlu "alat". Kita pasang:

| Tool | Fungsi |
|---|---|
| AWS CLI v2 | Bicara ke AWS dari terminal + simpan kredensial |
| Terraform | Mesin IaC |
| kubectl, helm, eksctl | Untuk mengelola Kubernetes (EKS) nanti |
| tflint | Memeriksa kualitas kode Terraform |
| docker, git, jq | Build image, version control, olah JSON |

Semua dipasang di `/usr/local/bin` (sistem). Perintah harian:
```bash
aws --version
terraform version
```

🖱️ **Manual:** Tidak ada "Console" untuk ini — toolchain selalu dipasang di komputer
Anda, bukan di AWS. Ini satu-satunya bagian yang memang manual.

---

### 3.2 Kredensial & IAM

**Apa & Kenapa:** AWS perlu tahu *siapa* Anda dan *boleh apa*. Identitas dipegang
oleh **IAM User** (`devfiqri`). Untuk akses dari CLI, user punya **Access Key**
(ID + Secret) — seperti username & password untuk program.

**Yang kita lakukan:** kunci lama (yang sempat bocor) **dirotasi** — buat kunci baru,
pasang, hapus kunci lama. Kunci aktif sekarang: `AKIA...5QNA`.

```bash
aws configure          # menyimpan kunci ke ~/.aws/credentials
aws sts get-caller-identity   # cek "saya login sebagai siapa"
```

🖱️ **Cara Manual di Console:**
1. Login Console → cari layanan **IAM**.
2. **Users** → **Create user** → beri nama → **Attach policies** (mis. `AdministratorAccess`).
3. Klik user → tab **Security credentials** → **Create access key** → pilih **CLI** → download `.csv`.
4. **Rotasi** (yang kita lakukan via CLI): buat key baru, ganti di `~/.aws/credentials`,
   lalu **Deactivate + Delete** key lama di tab yang sama.

> 💡 Langkah berikutnya yang disarankan (manual, di Console): aktifkan **MFA** di
> tab Security credentials user `devfiqri`.

---

### 3.3 Remote State (S3 + DynamoDB)

**Apa & Kenapa:** State Terraform harus aman & bisa diakses bersama. Kita simpan di:
- **S3 bucket** — menyimpan file `terraform.tfstate` (dengan versioning & enkripsi).
- **DynamoDB table** — "mengunci" state agar dua orang tidak apply bersamaan & bentrok.

**Cara Terraform:** folder [bootstrap/](../bootstrap/) — dijalankan sekali.
File kunci: [bootstrap/main.tf](../bootstrap/main.tf)
```hcl
resource "aws_s3_bucket" "state" { bucket = "cloudops-tfstate-586723123091" }
resource "aws_s3_bucket_versioning" ...        # riwayat
resource "aws_s3_bucket_server_side_encryption_configuration" ...  # enkripsi
resource "aws_s3_bucket_public_access_block" ...  # tutup publik
resource "aws_dynamodb_table" "lock" { hash_key = "LockID" ... }
```

🖱️ **Cara Manual di Console:**

*Bucket S3:*
1. Console → **S3** → **Create bucket**.
2. Nama: `cloudops-tfstate-586723123091`, Region: `ap-southeast-1`.
3. **Bucket Versioning** → Enable.
4. **Default encryption** → SSE-S3 (Amazon S3 managed).
5. **Block Public Access** → biarkan semua tercentang (ON).
6. **Create bucket**.

*Tabel DynamoDB:*
1. Console → **DynamoDB** → **Create table**.
2. Table name: `cloudops-tfstate-lock`.
3. Partition key: `LockID` tipe **String**.
4. Capacity mode: **On-demand**.
5. **Create table**.

Setelah itu, agar Terraform memakainya, isi blok backend ([dev/backend.tf](../environments/dev/backend.tf)):
```hcl
backend "s3" {
  bucket         = "cloudops-tfstate-586723123091"
  key            = "dev/terraform.tfstate"
  dynamodb_table = "cloudops-tfstate-lock"
}
```

---

### 3.4 Budget Guardrail

**Apa & Kenapa:** Pengaman agar tidak kaget tagihan. Memberi email saat biaya mendekati batas.

**Cara Terraform:** folder [global/](../global/) → [global/main.tf](../global/main.tf)
```hcl
resource "aws_budgets_budget" "monthly" {
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  notification { threshold = 80  notification_type = "ACTUAL" ... }
  notification { threshold = 100 notification_type = "FORECASTED" ... }
}
```

🖱️ **Cara Manual di Console:**
1. Console → pojok kanan atas nama akun → **Billing and Cost Management**.
2. Menu kiri → **Budgets** → **Create budget**.
3. Pilih **Cost budget** → Next.
4. Period: **Monthly**, Budget amount: **$20**.
5. **Add alert threshold**: 80% of **Actual**, email `sahrudinriri@gmail.com`.
6. Tambah lagi: 100% of **Forecasted**.
7. **Create budget**.

---

### 3.5 Jaringan / VPC

**Apa & Kenapa:** VPC = "data center virtual" pribadi Anda di AWS. Semua workload
berjalan di dalamnya. Komponennya:
- **Subnet publik** — punya akses langsung ke internet (untuk load balancer).
- **Subnet privat** — tersembunyi, aman (untuk server & database).
- **Internet Gateway (IGW)** — pintu ke internet untuk subnet publik.
- **Route Table** — "peta jalan" lalu lintas jaringan.
- **NAT Gateway** *(kita matikan, hemat ~$32/bln)* — agar subnet privat bisa
  *keluar* ke internet tanpa bisa *dimasuki*.

**Cara Terraform:** modul reusable [modules/networking/](../modules/networking/main.tf).
Satu blok `module` membuat **13 resource** sekaligus:
```hcl
module "networking" {
  source             = "../../modules/networking"
  vpc_cidr           = "10.10.0.0/16"
  az_count           = 2
  enable_nat_gateway = false   # ← hemat
}
```

🖱️ **Cara Manual di Console** (ini paling banyak klik — di sinilah Terraform sangat menghemat waktu):
1. Console → **VPC** → **Create VPC**.
   - Pilih **VPC only**, CIDR `10.10.0.0/16`, beri nama `cloudops-dev-vpc`.
   - Setelah jadi → **Actions → Edit DNS hostnames** → Enable.
2. **Internet Gateways** → **Create** → beri nama → **Actions → Attach to VPC**.
3. **Subnets** → **Create subnet** (ulangi **4×**):
   - `public-1` (AZ a, CIDR 10.10.0.0/20), `public-2` (AZ b, 10.10.16.0/20)
   - `private-1` (AZ a, 10.10.128.0/20), `private-2` (AZ b, 10.10.144.0/20)
   - Untuk 2 subnet publik: **Edit subnet settings → Enable auto-assign public IP**.
4. **Route Tables** → Create "public-rt" → **Routes → Edit** → tambah `0.0.0.0/0` → target **IGW** → **Subnet associations** → kaitkan 2 subnet publik.
5. Buat juga route table privat (tanpa rute internet karena NAT off), kaitkan 2 subnet privat.

> Bayangkan mengklik 13 resource ini **dua kali** (dev & prod) tanpa salah. Terraform
> melakukannya konsisten dalam hitungan detik — inilah inti nilainya.

---

### 3.6 Serverless (Lambda + API Gateway)

**Apa & Kenapa:** Menjalankan kode **tanpa mengelola server**. Lambda menjalankan
fungsi saat dipanggil; API Gateway memberi URL publik untuk memanggilnya. Bayar
hanya saat dipakai (free tier sangat besar).

**Cara Terraform:** modul [modules/serverless/](../modules/serverless/main.tf).
Kode fungsi ada di [modules/serverless/src/handler.py](../modules/serverless/src/handler.py) —
Terraform otomatis men-zip & meng-upload-nya.
```hcl
resource "aws_lambda_function" "this" { ... runtime = "python3.12" ... }
resource "aws_apigatewayv2_api" "this" { protocol_type = "HTTP" }
resource "aws_apigatewayv2_route" "this" { route_key = "ANY /{proxy+}" }
```
Hasil: **https://beruetroad.execute-api.ap-southeast-1.amazonaws.com** → balas `HTTP 200`.

🖱️ **Cara Manual di Console:**

*Lambda:*
1. Console → **Lambda** → **Create function** → **Author from scratch**.
2. Name `cloudops-dev-fn`, Runtime **Python 3.12** → **Create function**
   (IAM role eksekusi dibuat otomatis).
3. Tab **Code** → tulis/upload kode → **Deploy**.

*API Gateway:*
1. Console → **API Gateway** → **Create API** → **HTTP API** → Build.
2. **Add integration** → Lambda → pilih `cloudops-dev-fn`.
3. **Configure routes** → Method `ANY`, Path `/{proxy+}`.
4. Stage `$default` (auto-deploy) → **Create**.
5. Salin **Invoke URL**. (Console otomatis menambah izin agar API boleh memanggil Lambda.)

Uji:
```bash
curl https://beruetroad.execute-api.ap-southeast-1.amazonaws.com/
```

---

### 3.7 Data Lake (S3 + Glue + Athena)

**Apa & Kenapa:** Menyimpan data sebagai file murah di S3, tapi bisa di-query pakai
SQL — tanpa database yang menyala 24 jam.
- **S3** — tempat file data (raw, processed) + hasil query.
- **Glue Data Catalog** — "kamus" yang mendefinisikan skema tabel atas file S3.
- **Athena** — mesin query SQL serverless (bayar per data yang dipindai).

**Cara Terraform:** modul [modules/data-lake/](../modules/data-lake/main.tf)
```hcl
resource "aws_s3_bucket" "this" { for_each = local.buckets ... }   # 3 bucket
resource "aws_glue_catalog_database" "this" { name = "cloudops_dev_datalake" }
resource "aws_athena_workgroup" "this" { name = "cloudops-dev-wg" ... }
```

🖱️ **Cara Manual di Console:**

*S3 (3 bucket):* sama seperti [3.3](#33-remote-state-s3--dynamodb), buat 3 bucket
(`...-datalake-raw`, `...-processed`, `...-athena-results`).

*Glue database:*
1. Console → **AWS Glue** → **Data Catalog → Databases** → **Add database**.
2. Nama `cloudops_dev_datalake` → Create.

*Athena workgroup & query:*
1. Console → **Athena** → **Workgroups** → **Create workgroup** `cloudops-dev-wg`.
   Set **Query result location** ke `s3://cloudops-dev-athena-results-.../output/`.
2. **Query editor** → buat tabel (DDL yang kita pakai):
   ```sql
   CREATE EXTERNAL TABLE IF NOT EXISTS kontak (
     id int, nama string, kota string)
   ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
   LOCATION 's3://cloudops-dev-datalake-raw-586723123091/contoh/'
   TBLPROPERTIES ('skip.header.line.count'='1');
   ```
3. Jalankan query:
   ```sql
   SELECT kota, COUNT(*) AS jumlah FROM kontak GROUP BY kota;
   ```

> Catatan penting: **infrastruktur** (bucket, Glue DB, workgroup) dibuat sekali via
> Terraform. Tapi **mengisi data & menjalankan query** adalah aktivitas operasional
> harian — dilakukan via CLI/Console/aplikasi, bukan Terraform.

---

## 4. Terraform vs Manual

| Komponen | Resource | Klik manual diperlukan | Baris Terraform |
|---|---|---:|---:|
| Remote state | S3 + DynamoDB (5) | ~15 klik | ~40 baris (sekali) |
| Budget | 1 budget | ~7 klik | ~20 baris |
| VPC dev | 13 resource | ~40+ klik | 1 blok `module` |
| Serverless | 9 resource | ~15 klik | 1 blok `module` |
| Data Lake | 11 resource | ~25 klik | 1 blok `module` |

**Pelajaran:** untuk **sekali coba**, manual terasa lebih cepat. Tapi untuk
**konsistensi, pengulangan (dev→prod), dan kemampuan menghapus rapi**, Terraform
menang telak. Itu sebabnya cloud architect profesional memakai IaC.

---

## 5. Alur Kerja & Perintah Penting

### Menyalakan / mematikan workload
Cukup ubah `true`/`false` di [environments/dev/terraform.tfvars](../environments/dev/terraform.tfvars):
```hcl
enable_serverless = true
enable_data_lake  = true
enable_web_app    = false   # butuh NAT
```
lalu:
```bash
cd environments/dev
terraform plan      # preview
terraform apply     # terapkan
```

### Perintah harian
```bash
terraform plan              # lihat perubahan sebelum apply
terraform apply             # terapkan perubahan
terraform output            # lihat URL/endpoint hasil
terraform destroy           # hapus SEMUA resource environment ini
terraform state list        # daftar resource yang dikelola
terraform fmt -recursive    # rapikan format kode
tflint                      # cek kualitas kode
```

### Memeriksa kondisi AWS
```bash
aws sts get-caller-identity                    # saya siapa?
aws ec2 describe-vpcs                           # daftar VPC
aws lambda list-functions                       # daftar Lambda
aws s3 ls                                        # daftar bucket
```

---

## 6. Rincian Biaya

| Resource | Model biaya | Estimasi sekarang |
|---|---|---|
| S3 state + data lake | Per GB tersimpan | ~$0 (data sangat kecil) |
| DynamoDB lock | Per request (on-demand) | ~$0 |
| Budget | Gratis | $0 |
| VPC, subnet, IGW, route table | Gratis | $0 |
| **NAT Gateway** *(off)* | ~$0.045/jam + data | **$0** (dimatikan) |
| Lambda | Per request (1 jt/bln gratis) | ~$0 |
| API Gateway | Per request | ~$0 |
| Athena | ~$5 per TB di-scan | ~$0 (data kecil) |

**Total: ~$0/bln.** Yang perlu diwaspadai saat scale-up: **NAT Gateway** (~$32/bln),
**EKS control plane** (~$73/bln), **RDS** (~$12+/bln) — semua tetap *off* sampai Anda
nyalakan.

---

## 7. Cheat Sheet

```bash
# ── Lokasi penting ───────────────────────────────────────────
bootstrap/                 # remote state (jalan sekali)
global/                    # budget, account-wide
modules/<nama>/            # cetakan reusable
environments/dev/          # rangkaian dev  ← paling sering disentuh
environments/dev/terraform.tfvars   # SAKLAR nyala/mati workload

# ── Menyalakan workload ──────────────────────────────────────
# 1) edit terraform.tfvars: ubah enable_xxx = true
# 2) cd environments/dev && terraform apply
# 3) terraform output   → lihat URL/endpoint

# ── Workload yang butuh NAT (set enable_nat_gateway = true dulu) ──
#    web_app, database, eks
# ── Workload yang TIDAK butuh NAT (langsung murah) ──
#    serverless, data_lake

# ── Membersihkan (hemat biaya) ───────────────────────────────
terraform destroy          # di environments/dev, hapus semua workload dev
```

### Yang masih bisa Anda kembangkan
- Aktifkan **MFA** untuk `devfiqri` (Console).
- Coba **Web App** (ECS+ALB) — nyalakan `enable_nat_gateway` + `enable_web_app`.
- Replikasi setup ke **prod** (`environments/prod/`).
- Tambah **CI/CD** (GitHub Actions menjalankan `terraform plan` tiap perubahan).
- Naik kelas ke **IAM Identity Center (SSO)** untuk kredensial berumur-pendek.

---

> 🏆 Anda telah membangun fondasi cloud profesional: kredensial aman, remote state,
> guardrail biaya, jaringan, dan dua workload hidup — semuanya sebagai kode, dengan
> biaya ~$0. Selamat belajar, Cloud Architect! 🚀

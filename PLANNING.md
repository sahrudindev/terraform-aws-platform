# Cetak Biru Infrastruktur AWS dengan Terraform

> Dokumen perencanaan profesional untuk mengelola seluruh infrastruktur AWS
> Anda secara *Infrastructure as Code* (IaC).
>
> | Parameter | Nilai |
> |---|---|
> | Workload | Web App + Database, Serverless, EKS (Container), Data/Analytics |
> | Environment | `dev` dan `prod` (terisolasi penuh) |
> | Region utama | `ap-southeast-1` (Singapore) |
> | Level | Pemula → dirancang bertahap |
> | Tools | Terraform ≥ 1.9, AWS CLI v2 |

---

## 1. Prinsip Dasar (Filosofi)

Sebelum menulis kode, ini aturan main yang membuat setup tetap rapi & aman:

1. **Semua lewat kode, tidak ada klik manual.** Begitu Terraform mengelola
   sebuah resource, jangan ubah lewat Console AWS — nanti *drift* (kode dan
   kenyataan beda). Console hanya untuk *melihat*, bukan *mengubah*.
2. **State disimpan remote, bukan di laptop.** State Terraform berisi data
   sensitif & jadi sumber kebenaran. Simpan di S3 + kunci dengan DynamoDB.
3. **`dev` dan `prod` benar-benar terpisah.** State terpisah, folder terpisah,
   idealnya nanti account AWS terpisah. Kesalahan di `dev` tidak boleh bisa
   merusak `prod`.
4. **Reusable modules.** Tulis sekali (mis. modul VPC), pakai di `dev` & `prod`
   dengan parameter berbeda. Jangan copy-paste.
5. **Least privilege & hemat biaya.** Beri izin seminimal mungkin; pasang alarm
   biaya sejak hari pertama.
6. **Mulai kecil, kembangkan bertahap.** Jangan bangun semua workload sekaligus.
   Ikuti urutan fase di bawah.

---

## 2. Arsitektur Target (Gambaran Besar)

```
                         AWS Account (Owner)
   ┌──────────────────────────────────────────────────────────┐
   │                                                          │
   │   GLOBAL (account-wide)                                  │
   │   • IAM roles/policies   • Route53   • Billing alarm     │
   │                                                          │
   │   ┌─────────────── dev ───────────┐  ┌──────── prod ────┐│
   │   │  VPC (10.10.0.0/16)           │  │ VPC (10.20.0.0/16)││
   │   │   ├─ Web App (ECS/ALB)        │  │  ├─ Web App       ││
   │   │   ├─ Serverless (Lambda+APIGW)│  │  ├─ Serverless    ││
   │   │   ├─ EKS (container)          │  │  ├─ EKS           ││
   │   │   ├─ RDS (database)           │  │  ├─ RDS           ││
   │   │   └─ Data Lake (S3+Glue+Athena)  │  └─ Data Lake     ││
   │   └───────────────────────────────┘  └──────────────────┘│
   └──────────────────────────────────────────────────────────┘

   State backend (dibuat sekali oleh "bootstrap"):
   S3 bucket  →  menyimpan terraform.tfstate
   DynamoDB   →  mengunci state agar tidak bentrok
```

---

## 3. Struktur Folder Repository

```
Terraform_AWS/
├── PLANNING.md              ← dokumen ini
├── README.md                ← panduan cepat
├── .gitignore               ← jangan commit state / secret
│
├── bootstrap/               ← FASE 1: buat S3 + DynamoDB untuk state (sekali jalan)
│   ├── main.tf
│   └── variables.tf
│
├── modules/                 ← komponen reusable (ditulis sekali)
│   ├── networking/          ← VPC, subnet, NAT, IGW, route table
│   ├── web-app/             ← ALB + ECS Fargate (atau EC2)
│   ├── serverless/          ← Lambda + API Gateway
│   ├── eks/                 ← cluster EKS + node group
│   ├── database/            ← RDS (PostgreSQL/MySQL)
│   └── data-lake/           ← S3 + Glue + Athena
│
├── environments/            ← konfigurasi per-environment
│   ├── dev/
│   │   ├── main.tf          ← panggil modules dengan parameter dev
│   │   ├── variables.tf
│   │   ├── terraform.tfvars ← nilai khusus dev (instance kecil, dst.)
│   │   └── backend.tf       ← state dev di S3
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars ← nilai khusus prod
│       └── backend.tf
│
└── global/                  ← resource account-wide (IAM, Route53, alarm biaya)
    ├── main.tf
    └── backend.tf
```

**Mengapa begini?** Modul = "cetakan", environment = "hasil cetak dengan ukuran
berbeda". `dev` pakai instance kecil & 1 NAT; `prod` pakai instance besar &
multi-AZ — kodenya sama, hanya nilai variabel beda.

---

## 4. Roadmap Bertahap (Eksekusi)

Setiap fase = satu langkah yang bisa diselesaikan & dites sebelum lanjut.
Ini penting untuk pemula: **jangan lompat fase.**

### Fase 0 — Persiapan (di laptop, ~30 menit)
- [ ] Install **Terraform** (≥ 1.9) dan **AWS CLI v2**.
- [ ] Buat **IAM User** khusus untuk Terraform (jangan pakai root account!).
      Beri akses programmatic (Access Key) + policy admin sementara.
- [ ] `aws configure` → masukkan Access Key, region `ap-southeast-1`.
- [ ] Aktifkan **MFA** di root account & IAM user.
- [ ] Pasang **Billing Alarm** (mis. notifikasi jika tagihan > $10) —
      pengaman pertama dari kejutan biaya.
- **Hasil:** `aws sts get-caller-identity` menampilkan identitas Anda.

### Fase 1 — Bootstrap Remote State (~20 menit)
- [ ] Folder `bootstrap/`: buat 1 S3 bucket (versioning + enkripsi) +
      1 DynamoDB table (lock).
- [ ] `terraform apply` di `bootstrap/` (state-nya lokal, hanya sekali ini).
- **Hasil:** tempat penyimpanan state siap. Semua fase berikutnya pakai ini.

### Fase 2 — Networking Foundation (~1 jam)
- [ ] Tulis `modules/networking/` (VPC, public+private subnet di 2 AZ, IGW, NAT).
- [ ] Pakai di `environments/dev/` lalu `prod/`.
- **Hasil:** fondasi jaringan tempat semua workload nanti berjalan.

### Fase 3 — Web App + Database (~2 jam)
- [ ] `modules/web-app/` (ALB + ECS Fargate) dan `modules/database/` (RDS).
- [ ] Deploy ke `dev` dulu, tes, baru `prod`.
- **Hasil:** aplikasi web pertama online dengan database.

### Fase 4 — Serverless
- [ ] `modules/serverless/` (Lambda + API Gateway + DynamoDB jika perlu).
- **Hasil:** endpoint API event-driven, bayar per request.

### Fase 5 — Container / EKS
- [ ] `modules/eks/` (cluster + managed node group / Fargate profile).
- ⚠️ EKS punya biaya tetap (~$0.10/jam per cluster). Nyalakan di `dev` hanya
      saat dipakai.
- **Hasil:** platform Kubernetes untuk workload container skala besar.

### Fase 6 — Data / Analytics
- [ ] `modules/data-lake/` (S3 bucket berlapis, Glue Catalog, Athena).
- **Hasil:** data lake untuk query & analitik.

### Fase 7 — Otomatisasi & Guardrail
- [ ] `.gitignore` benar (state & `.tfvars` rahasia tidak ke-commit).
- [ ] CI/CD: GitHub Actions jalankan `terraform plan` di setiap PR.
- [ ] Tambah `tflint` + `checkov` (cek keamanan otomatis).
- [ ] Pertimbangkan **AWS Organizations** → account `dev` & `prod` terpisah.
- **Hasil:** perubahan aman, tertinjau, dan otomatis.

---

## 5. Konvensi & Standar

| Aspek | Standar |
|---|---|
| Penamaan resource | `{project}-{env}-{resource}` mis. `myapp-dev-vpc` |
| Tag wajib | `Environment`, `Project`, `ManagedBy=Terraform`, `Owner` |
| Versi provider | Pin di `required_providers` (mis. `~> 5.0`) |
| Format kode | Wajib `terraform fmt` sebelum commit |
| Secret | Jangan hardcode → pakai AWS Secrets Manager / SSM Parameter Store |
| Workflow | `plan` → review → baru `apply`. Jangan `apply` membabi buta. |

---

## 6. Estimasi & Catatan Biaya (penting untuk pemula)

- **Gratis/murah:** S3, DynamoDB lock, Lambda (free tier besar), state backend.
- **Biaya tetap walau idle:** NAT Gateway (~$32/bln), EKS control plane
  (~$73/bln), RDS (tergantung instance). → Matikan/`destroy` `dev` saat tidak
  dipakai.
- **Kebiasaan baik:** `terraform destroy` di `dev` setiap selesai eksperimen.
- Billing alarm (Fase 0) adalah jaring pengaman utama Anda.

---

## 7. Langkah Selanjutnya

Planning ini siap dieksekusi. Rekomendasi saya: kerjakan **Fase 0 → 1 → 2**
lebih dulu sebagai fondasi, lalu pilih satu workload (biasanya Web App + DB)
sebagai workload pertama.

Saya bisa langsung men-*scaffold* (membuatkan kerangka file & kode) untuk:
1. `bootstrap/` (remote state) — titik mulai paling aman, atau
2. `modules/networking/` + `environments/dev/` — fondasi jaringan.

Cukup beri tahu mau mulai dari mana.

# Roadmap Portofolio Cloud Engineer — AWS + Terraform

> Dokumen kerja internal. Rencana mengubah repo ini dari *sandbox belajar*
> menjadi *bukti kerja profesional* yang lolos screening technical reviewer.
>
> | | |
> |---|---|
> | Repo | `github.com/sahrudindev/terraform-aws-platform` (private → akan dipublikkan) |
> | Target peran | Cloud Engineer / Cloud Infrastructure Engineer / Platform Engineer |
> | Target pasar | Indonesia + remote internasional (dokumen utama Bahasa Inggris) |
> | Status audit | 27 Agustus 2026 |

---

## Progres (diperbarui 27 Agustus 2026)

| Fase | Status | Catatan |
|---|---|---|
| 0 — Toolchain & AWS | ✅ | Terraform 1.16.0 + tflint, checkov, trivy, terraform-docs, gitleaks, infracost. |
| 1 — Brownfield import | ⬜ tidak berlaku | Account target tidak memuat resource `cloudops` apa pun. ADR-0001 disimpan sebagai prosedur bila nanti dibutuhkan. |
| 2 — Higienis repo | ✅ | Lock file di-commit, partial backend config, provider v6.62.0, `use_lockfile`, LICENSE, README Inggris + diagram. |
| 3 — CI/CD OIDC | ✅ | Berjalan sungguhan. Plan diposting ke PR, apply berhenti menunggu approval, nol access key. |
| 4 — Testing | 🟡 | 12 run / 18 assertion untuk networking & database. Modul web-app, serverless, data-lake, eks, kms belum punya test. |
| 5 — Security | ✅ putaran pertama | checkov 494/0/86, trivy 0, gitleaks bersih. |
| 6 — Flagship + live demo | 🟡 | Endpoint serverless hidup dan bisa diklik. Pipeline data penuh (S3 → EventBridge → Glue → Athena) belum. |
| 7 — Observability | ⬜ | Modul `observability` belum dibuat. |
| 8 — Presentasi | 🟡 | README, ARCHITECTURE, TEARDOWN, 5 ADR, SECURITY, laporan scan, 24 commit. Belum ada screenshot atau video demo. |

**Hidup di AWS:** bucket state (CMK, versioned, TLS-only, `prevent_destroy`), VPC dev
`10.10.0.0/16` dengan 4 subnet dan flow logs, 2 KMS key, dan endpoint serverless.
Nol NAT Gateway, nol EKS, nol RDS, nol ALB. Sekitar **$2–3/bulan**, hampir seluruhnya KMS.

**Catatan pengukuran CI.** Job `fmt / validate / lint`: 167 detik tanpa cache, 79 detik
setelah `TF_PLUGIN_CACHE_DIR`, 77 detik dengan `actions/cache` hangat. Jadi seluruh
penghematan datang dari berbagi direktori plugin **di dalam satu job**; menyimpannya
antar-run praktis tidak berpengaruh, karena mengunggah dan mengunduh ~900 MB memakan
waktu sebanding dengan yang dihemat. `actions/cache` dipertahankan untuk mengurangi
ketergantungan pada registry Terraform, bukan demi kecepatan.

**Berikutnya:** test untuk modul yang belum punya, modul observability, dan pipeline
data penuh di atas endpoint yang sudah hidup.
(budget + role OIDC). Setelah ARN role masuk sebagai repository variable, job `plan` berhenti
di-skip dan CI menjadi bukti yang bisa ditunjukkan.

---

## 1. Ringkasan Eksekutif

**Kondisi sekarang:** struktur repo sudah benar secara arsitektur (module/environment
terpisah, remote state, feature flag biaya). Ini di atas rata-rata portofolio pemula.

**Masalahnya:** repo ini masih terbaca sebagai *tutorial yang belum dijalankan*,
bukan *sistem yang hidup*. Tidak ada CI/CD, tidak ada test, tidak ada bukti apa pun
bahwa kode ini pernah berhasil di-apply, dan ada beberapa kesalahan konvensi yang
langsung terlihat oleh reviewer senior dalam 2 menit pertama.

**Yang paling membedakan kandidat** (dan hampir tidak pernah ada di portofolio junior):

1. CI/CD Terraform dengan **GitHub OIDC** (tanpa access key jangka panjang)
2. **Automated testing** (`.tftest.hcl`) + security scanning di setiap PR
3. **Brownfield import** — mengambil alih resource AWS yang sudah terlanjur dibuat manual
4. **Bukti nyata**: live demo URL, screenshot, output `plan`, laporan biaya

Poin 3 kebetulan adalah masalah Anda sekarang ("sudah ada yang di-deploy, koneksi ke
Terraform-nya belum"). Itu bukan hambatan — itu justru bahan portofolio terbaik,
karena inilah pekerjaan Cloud Engineer di dunia nyata.

**Prinsip utama:** dua workload dikerjakan sempurna jauh lebih bernilai daripada
lima workload setengah jadi. Rencana di bawah menyempitkan fokus, bukan memperlebar.

---

## 2. Hasil Audit Kode

### 2.1 Yang sudah bagus (pertahankan)

| Hal | Kenapa bernilai |
|---|---|
| Pemisahan `modules/` vs `environments/` | Bukan satu `main.tf` raksasa. Ini pola yang benar. |
| `bootstrap/` untuk remote state | Menunjukkan paham *chicken-and-egg problem* state backend. |
| `manage_master_user_password = true` di RDS | Password otomatis ke Secrets Manager, nol plaintext. Ini di atas level pemula. |
| `aws_vpc_security_group_ingress_rule` + `for_each` | Resource SG modern, bukan blok `ingress` inline yang usang. |
| `default_tags` di provider | Tagging konsisten tanpa duplikasi. |
| Feature flag `enable_*` | Kesadaran biaya sejak awal — sinyal FinOps yang bagus. |
| Budget + alarm di `global/` | Guardrail sejak hari pertama. |
| CIDR subnet dihitung `cidrsubnet()` | Bukan hardcode. Benar. |

### 2.2 Temuan yang harus diperbaiki

Severity: 🔴 kritis (reviewer langsung menilai negatif) · 🟠 penting · 🟡 poles

| # | Sev | Temuan | Perbaikan |
|---|---|---|---|
| 1 | 🔴 | `.terraform.lock.hcl` masuk `.gitignore` | **Harus di-commit.** Lock file menjamin semua orang & CI pakai versi provider identik. Ini kesalahan konvensi paling terkenal. |
| 2 | 🔴 | Tidak ada CI/CD sama sekali | GitHub Actions: `fmt`/`validate`/`tflint`/`checkov`/`plan` di setiap PR. Gap terbesar untuk peran Cloud Engineer. |
| 3 | 🔴 | Tidak ada test | `tests/*.tftest.hcl` (Terraform ≥1.6). Gratis (`command = plan`), hampir tak ada pesaing yang punya. |
| 4 | 🔴 | Toolchain tidak terpasang; README mengklaim sudah | Terraform tidak ada di sistem. Pasang via `tenv`, pin di `.terraform-version`. Perbaiki klaim README. |
| 5 | 🔴 | Belum ada kredensial AWS & belum ada koneksi ke resource yang sudah di-deploy | Fase 0 + Fase 1 (brownfield import). |
| 6 | 🟠 | Account ID `123456789012` hardcoded di 3 `backend.tf` + `BELAJAR.md` | Pakai *partial backend config*: `backend.hcl` (gitignored) + `terraform init -backend-config=backend.hcl`. Commit `backend.hcl.example`. |
| 7 | 🟠 | `dynamodb_table` untuk state lock sudah deprecated | Terraform ≥1.10 punya native S3 lock: `use_lockfile = true`. DynamoDB boleh dihapus setelah migrasi. |
| 8 | 🟠 | Provider AWS dipin `~> 5.0` | v6.x sudah lama rilis. Upgrade + sesuaikan breaking change (mis. `data.aws_region.current.name` → `.region`). |
| 9 | 🟠 | `*.tfvars` di-ignore total, tidak ada contoh | Reviewer tidak bisa menjalankan repo. `global/` bahkan gagal apply karena `alert_emails` tanpa default. Tambah `*.tfvars.example` di tiap env. |
| 10 | 🟠 | Tidak ada IAM role OIDC untuk GitHub Actions | Tanpa ini, CI butuh access key jangka panjang = nilai minus besar. |
| 11 | 🟠 | ALB HTTP saja (port 80), tanpa ACM/HTTPS | Tambah ACM cert, listener 443, redirect 80→443, access logs, `drop_invalid_header_fields`. |
| 12 | 🟠 | Tidak ada VPC Flow Logs | Langsung di-flag `checkov`. Tambah flow log ke CloudWatch/S3. |
| 13 | 🟠 | EKS: tanpa OIDC/IRSA, tanpa addon, tanpa control-plane logging, tanpa enkripsi secret, endpoint publik terbuka | Semua ini standar produksi. Juga `kubernetes_version = "1.31"` sudah lewat masa standard support. |
| 14 | 🟠 | S3 pakai AES256, tanpa bucket policy tolak non-TLS, tanpa lifecycle | Naikkan ke KMS CMK + rotasi, policy `aws:SecureTransport = false → Deny`, lifecycle untuk versi lama. |
| 15 | 🟠 | RDS: tanpa Performance Insights / enhanced monitoring / log export; `engine_version` dipin ke patch `16.4` | Pin ke major saja (`"16"`) agar minor upgrade tidak menimbulkan drift. |
| 16 | 🟠 | ECS: tanpa autoscaling, tanpa deployment circuit breaker, image dari public ECR | Tambah `aws_appautoscaling_*`, circuit breaker + rollback, dan ECR repo sendiri. |
| 17 | 🟡 | Lambda: tanpa X-Ray tracing, tanpa DLQ, tanpa reserved concurrency | Murah ditambahkan, terlihat matang. |
| 18 | 🟡 | Egress SG `0.0.0.0/0` di semua modul | Persempit minimal di `prod`. |
| 19 | 🟡 | `prod` hardcode `enable_nat_gateway = true`, `dev` pakai variabel | Samakan agar konsisten. |
| 20 | 🟡 | Tidak ada README per-module, tidak ada `terraform-docs` | Auto-generate tabel Inputs/Outputs tiap modul. |
| 21 | 🟡 | Tidak ada diagram arsitektur | README wajib dibuka dengan satu diagram. |
| 22 | 🟡 | Tidak ada LICENSE / CODEOWNERS / `.editorconfig` / `pre-commit` | Kelengkapan repo profesional. |
| 23 | 🟡 | Riwayat commit: 2 commit, pesan `"first commit"` & `"baru"` | Reviewer membaca history. Mulai sekarang pakai Conventional Commits. |
| 24 | 🟡 | Komentar sangat padat & berbahasa Indonesia di kode modul | Bagus untuk belajar, tapi kode produksi lebih ringkas. Pindahkan penjelasan panjang ke `docs/`, sisakan komentar "kenapa" (bukan "apa") dalam Bahasa Inggris. |

---

## 3. Strategi Positioning

### 3.1 Masalah narasi saat ini

Repo sekarang menawarkan lima workload (web app, serverless, EKS, database, data lake)
yang **semuanya default mati**. Bagi reviewer, ini terbaca: banyak scaffolding, nol bukti.

### 3.2 Narasi yang direkomendasikan

Karena konteks kerja Anda condong ke data (`Auto_Data_idn`) dan sudah ada modul
data-lake, posisikan diri sebagai **Cloud Engineer dengan kekuatan data platform**.
Ini pasar yang lebih sepi pesaing dan lebih tinggi bayarannya.

**Flagship — "Serverless Data Platform on AWS, 100% Infrastructure as Code"**

```
API Gateway ──▶ Lambda (ingest) ──▶ S3 raw ──▶ EventBridge
                                                    │
                                                    ▼
                                     Lambda / Glue (transform → Parquet)
                                                    │
                                                    ▼
                       S3 curated ──▶ Glue Catalog ──▶ Athena ──▶ dashboard
```

Kenapa ini pilihan terbaik:
- Biayanya **mendekati nol** di skala portofolio → **bisa dibiarkan hidup 24/7**
- Artinya README bisa memuat **live demo URL yang benar-benar bisa diklik recruiter**
- Menunjukkan serverless, event-driven, data engineering, dan IaC sekaligus

**Pendukung — deploy → screenshot → destroy**
- **ECS Fargate 3-tier + RDS + ALB/HTTPS** — bukti kemampuan VPC & container klasik
- **EKS** — bukti Kubernetes. Nyalakan 1 hari, ambil bukti, `destroy`.

**Lapisan pembeda (ini yang sebenarnya dinilai)**
CI/CD OIDC · testing · security scanning · cost visibility · dokumentasi · ADR.

### 3.3 Aturan main

- Yang tidak dikerjakan sampai selesai, **hapus dari repo** — bukan dibiarkan sebagai flag mati.
- Setiap fase berakhir dengan **artefak yang bisa ditunjukkan** (badge, screenshot, URL, laporan).
- Setiap keputusan arsitektur non-trivial ditulis sebagai ADR di `docs/adr/`.

---

## 4. Roadmap

### Fase 0 — Sambungkan kembali toolchain & AWS  🔴 BLOKIR SEMUANYA
**Estimasi: 2–3 jam**

- [ ] Pasang manajer versi Terraform (`tenv`), buat `.terraform-version` (pakai rilis stabil terbaru, minimal 1.10 agar `use_lockfile` tersedia)
- [ ] Pasang: `tflint`, `checkov`, `trivy`, `infracost`, `terraform-docs`, `pre-commit`, `gitleaks`
- [ ] Buat **IAM user/role khusus Terraform** (jangan root). Aktifkan MFA di root & IAM user
- [ ] `aws configure` (atau lebih baik: IAM Identity Center / `aws configure sso`) untuk region `ap-southeast-1`
- [ ] Verifikasi: `aws sts get-caller-identity` menampilkan account `123456789012`
- [ ] Cek apakah bucket state `cloudops-tfstate-123456789012` & tabel lock benar-benar ada

**Deliverable:** `terraform version` & `aws sts get-caller-identity` berhasil.

---

### Fase 1 — Adopsi resource AWS yang sudah terlanjur di-deploy  🔴
**Estimasi: 4–8 jam** · *Ini yang Anda tanyakan: "cara koneksi ke terraform-nya"*

- [ ] **Inventarisasi** apa saja yang hidup di account:
  ```bash
  aws resourcegroupstaggingapi get-resources --region ap-southeast-1 \
    --query 'ResourceTagMappingList[].ResourceARN' --output table
  ```
  Lengkapi dengan `aws ec2 describe-vpcs`, `describe-instances`, `s3 ls`,
  `rds describe-db-instances`, `lambda list-functions`, `eks list-clusters`
- [ ] Tentukan status tiap resource: **(a)** sudah ada di state Terraform, **(b)** dibuat manual → perlu di-import, **(c)** sampah → hapus
- [ ] `terraform init -backend-config=backend.hcl` di tiap environment, lalu `terraform plan` untuk melihat apa yang sudah dikenali state
- [ ] Untuk resource yang belum dikenali, gunakan **`import` block** (Terraform ≥1.5) — deklaratif dan terlihat di `plan`, bukan `terraform import` via CLI:
  ```hcl
  import {
    to = module.networking.aws_vpc.this
    id = "vpc-0abc123..."
  }
  ```
- [ ] Untuk resource tanpa kode HCL, generate otomatis:
  ```bash
  terraform plan -generate-config-out=generated.tf
  ```
  lalu rapikan hasilnya ke dalam modul yang sesuai
- [ ] **Target akhir: `terraform plan` menghasilkan "No changes"** untuk seluruh resource yang sudah hidup
- [ ] Hapus semua `import` block setelah berhasil (sudah tercatat di state)
- [ ] Tulis `docs/adr/0001-brownfield-import.md` — apa yang di-import, kendalanya, cara verifikasi

**Deliverable:** output `terraform plan` bersih + catatan proses import.
**Nilai wawancara:** ini persis pekerjaan hari pertama seorang Cloud Engineer di
perusahaan yang infranya masih ClickOps. Ceritakan ini dan Anda langsung terdengar berpengalaman.

---

### Fase 2 — Higienis repo & kredibilitas  🔴
**Estimasi: 3–4 jam · dampak tertinggi per jam**

- [ ] Hapus `.terraform.lock.hcl` dari `.gitignore`, **commit lock file** semua modul & env
- [ ] Migrasi ke *partial backend config*:
  - buat `backend.hcl` per env (gitignored) + `backend.hcl.example` (di-commit)
  - hapus account ID dari `backend.tf`, `README.md`, `docs/BELAJAR.md`
- [ ] Migrasi state lock: tambah `use_lockfile = true`, hapus `dynamodb_table`
- [ ] Upgrade provider AWS ke `~> 6.0`; jalankan `terraform plan` dan perbaiki breaking change
- [ ] Tambah `dev/terraform.tfvars.example` & `prod/terraform.tfvars.example` & `global/terraform.tfvars.example`
- [ ] Beri `default` pada `alert_emails` atau dokumentasikan jelas bahwa wajib diisi
- [ ] Samakan `enable_nat_gateway` di `prod` agar pakai variabel seperti `dev`
- [ ] Tambah `LICENSE` (MIT), `.editorconfig`, `CODEOWNERS`, `CONTRIBUTING.md`
- [ ] **Tulis ulang `README.md` dalam Bahasa Inggris**: diagram di paling atas, badge CI,
      quickstart, tabel biaya, link live demo. Simpan `docs/BELAJAR.md` (Indonesia) sebagai nilai tambah
- [ ] Mulai pakai **Conventional Commits** (`feat:`, `fix:`, `ci:`, `docs:`, `refactor:`)

**Deliverable:** repo yang bisa di-clone orang lain dan langsung jalan.

---

### Fase 3 — CI/CD dengan GitHub OIDC  🟠 PEMBEDA #1
**Estimasi: 6–8 jam**

- [ ] Di `global/`: buat `aws_iam_openid_connect_provider` untuk `token.actions.githubusercontent.com`
- [ ] Dua IAM role dengan trust policy dibatasi ke repo & branch Anda:
  - `gha-terraform-plan` → read-only (`ReadOnlyAccess` + tulis ke state bucket)
  - `gha-terraform-apply` → izin sesuai kebutuhan, dibatasi ke branch `main`
- [ ] `.github/workflows/terraform-plan.yml` (trigger: `pull_request`):
  `fmt -check` → `validate` → `tflint` → `checkov` → `trivy config` → `plan` → `infracost diff`
  → posting hasil `plan` + estimasi biaya sebagai **komentar PR**
- [ ] `.github/workflows/terraform-apply.yml` (trigger: `push` ke `main`):
  pakai **GitHub Environment** dengan *required reviewer* (approval manual sebelum apply)
- [ ] Matrix `dev` / `prod`; `concurrency` group agar tidak ada apply paralel
- [ ] Aktifkan branch protection di `main`: wajib PR, wajib status check hijau
- [ ] Tambah badge status workflow di README

**Deliverable:** screenshot komentar PR berisi `terraform plan` + estimasi biaya Infracost.
**Nilai wawancara:** "Tidak ada satu pun AWS access key jangka panjang di repo saya —
CI mengambil kredensial sementara lewat OIDC." Ini kalimat yang membuat reviewer berhenti membaca CV lain.

---

### Fase 4 — Testing & quality gate  🟠 PEMBEDA #2
**Estimasi: 5–7 jam**

- [ ] `modules/*/tests/*.tftest.hcl` dengan `command = plan` (gratis, tanpa biaya AWS):
  - networking: jumlah subnet sesuai `az_count`, CIDR tidak tumpang tindih, NAT nol saat flag mati
  - database: `deletion_protection` wajib `true` saat `environment = "prod"`
  - web-app: SG service hanya menerima dari SG ALB
  - penamaan & tag wajib ada di semua resource
- [ ] Minimal satu test `command = apply` untuk modul serverless (murah) — dijalankan di CI
- [ ] Opsional: satu integration test **Terratest** (Go) — deploy nyata → assert HTTP 200 → destroy
- [ ] `.pre-commit-config.yaml`: `terraform_fmt`, `terraform_validate`, `terraform_tflint`,
      `terraform_docs`, `gitleaks`, `check-merge-conflict`
- [ ] `terraform-docs` auto-inject tabel Inputs/Outputs ke README tiap modul (dicek di CI)

**Deliverable:** badge test hijau + `docs/TESTING.md`.

---

### Fase 5 — Security hardening  🟠 PEMBEDA #3
**Estimasi: 8–12 jam**

- [ ] Jalankan `checkov -d . --compact` → **simpan skor awal** (ini baseline "before")
- [ ] Perbaiki temuan; yang sengaja dilewati diberi `#checkov:skip=CKV_...:alasan` yang jujur
- [ ] KMS CMK + rotasi otomatis untuk S3, RDS, CloudWatch Logs, EKS secret envelope encryption
- [ ] Bucket policy S3: `Deny` bila `aws:SecureTransport = false`
- [ ] S3 lifecycle: expire noncurrent version (termasuk bucket state)
- [ ] VPC Flow Logs → CloudWatch Logs
- [ ] ALB: ACM cert + listener 443 + redirect 80→443 + access logs + WAFv2 managed rules
- [ ] IAM least privilege: ganti AWS managed policy dengan custom policy bila memungkinkan
- [ ] EKS: OIDC provider + IRSA, control plane logging, addon (`vpc-cni`, `coredns`, `kube-proxy`, `ebs-csi`), endpoint privat + CIDR allowlist, naikkan versi Kubernetes ke yang masih *standard support*
- [ ] RDS: Performance Insights, enhanced monitoring, export log ke CloudWatch, IAM auth, pin `engine_version` ke major saja
- [ ] Lambda: X-Ray tracing, SQS DLQ, reserved concurrency
- [ ] Di `global/`: aktifkan GuardDuty + Security Hub + AWS Config (catat biayanya di README)
- [ ] Tulis `docs/SECURITY.md` + **tabel before/after skor checkov di README**

**Deliverable:** tabel "Security posture: 47 findings → 3 accepted risks (documented)".
Ini salah satu artefak paling meyakinkan yang bisa Anda tunjukkan.

---

### Fase 6 — Bangun flagship + live demo  🟠
**Estimasi: 10–15 jam**

- [ ] Lengkapi modul serverless jadi pipeline data penuh (API GW → Lambda → S3 → EventBridge → transform → Glue → Athena)
- [ ] DynamoDB untuk idempotency + SQS DLQ + Step Functions untuk orkestrasi
- [ ] Konversi ke Parquet + partisi by date; Glue Crawler
- [ ] Dataset contoh (data publik Indonesia agar relevan secara lokal)
- [ ] **Biarkan hidup 24/7** — biayanya mendekati nol
- [ ] Taruh **live demo URL di baris pertama README**
- [ ] Screenshot hasil query Athena + dashboard

**Deliverable:** URL yang bisa diklik recruiter dan langsung mengembalikan data nyata.

---

### Fase 7 — Observability & operations  🟡
**Estimasi: 5–6 jam**

- [ ] `modules/observability/`: CloudWatch dashboard sebagai kode, SNS topic → email/Slack
- [ ] Alarm: Lambda error rate & throttle, ALB 5xx & target health, RDS CPU/storage/connections, ECS task failure, biaya NAT
- [ ] `docs/RUNBOOK.md` — gejala → diagnosis → tindakan, untuk 5 skenario insiden
- [ ] `docs/DISASTER-RECOVERY.md` — RTO/RPO, prosedur restore state & database
- [ ] AWS Cost Anomaly Detection

**Deliverable:** screenshot dashboard + runbook.

---

### Fase 8 — Lapisan presentasi (yang dilihat HRD)  🟡
**Estimasi: 6–8 jam**

- [ ] Diagram arsitektur: Mermaid di README + satu PNG rapi (`diagrams` Python / draw.io)
- [ ] `docs/adr/` — 5–8 ADR: kenapa ECS bukan EKS, kenapa OIDC bukan access key, kenapa module lokal bukan registry, strategi multi-account, dsb.
- [ ] `docs/COST.md` — rincian biaya dev vs prod, output Infracost
- [ ] **Video demo 2–3 menit**: PR dibuka → CI jalan → plan muncul di komentar → merge → apply → resource hidup di Console
- [ ] Pin repo di profil GitHub; rapikan profil README
- [ ] Tulis 1 artikel (LinkedIn/dev.to) tentang Fase 1 (brownfield import) — konten paling langka & paling dicari
- [ ] Publikasikan repo (setelah dipastikan tidak ada rahasia — jalankan `gitleaks detect`)

**Deliverable:** repo publik yang layak di-pin dan dibagikan.

---

### Fase 9 — Lanjutan (untuk melompat ke level mid/senior)  ⚪
*Kerjakan hanya setelah Fase 0–8 selesai.*

- [ ] Multi-account via AWS Organizations (account `dev`/`prod`/`security` terpisah)
- [ ] Publikasikan satu modul ke **Terraform Registry** (sinyal sangat kuat)
- [ ] Policy-as-code: OPA/Conftest sebagai gate di CI
- [ ] Blue/green deployment ECS via CodeDeploy
- [ ] Self-hosted runner di dalam VPC, atau Atlantis
- [ ] Kubernetes GitOps: ArgoCD/Flux di atas EKS

---

## 5. Prioritas

### Matriks dampak vs usaha

| | Usaha rendah | Usaha tinggi |
|---|---|---|
| **Dampak tinggi** | **Fase 2** (higienis repo), commit lock file, README + diagram | **Fase 1** (import), **Fase 3** (CI/CD OIDC), **Fase 5** (security) |
| **Dampak sedang** | LICENSE, terraform-docs, Conventional Commits | **Fase 4** (test), **Fase 6** (flagship), **Fase 7** (observability) |

### Jalur cepat 2 minggu (jika sedang aktif melamar)

| Hari | Fokus |
|---|---|
| 1 | Fase 0 — toolchain + kredensial AWS |
| 2–3 | Fase 1 — import resource yang sudah hidup sampai `plan` bersih |
| 4 | Fase 2 — lock file, backend partial, provider v6, tfvars.example |
| 5 | Fase 2 — README Inggris + diagram Mermaid + LICENSE |
| 6–7 | Fase 3 — OIDC + workflow plan-on-PR |
| 8 | Fase 3 — workflow apply + branch protection + badge |
| 9–10 | Fase 4 — `.tftest.hcl` + pre-commit + terraform-docs |
| 11–12 | Fase 5 — checkov sampai bersih, tabel before/after |
| 13 | Fase 6 — flagship serverless hidup + live URL |
| 14 | Fase 8 — video demo, ADR, publikasikan, posting LinkedIn |

Fase 7 dan 9 menyusul setelahnya.

---

## 6. Bentuk akhir repo

```
terraform-aws-platform/
├── README.md                    ← Inggris, diagram, badge, live demo URL
├── LICENSE  CODEOWNERS  .editorconfig  .terraform-version
├── .pre-commit-config.yaml  .tflint.hcl  .checkov.yaml  infracost.yml
├── .github/
│   ├── workflows/  terraform-plan.yml · terraform-apply.yml · security.yml
│   └── CODEOWNERS  pull_request_template.md
├── docs/
│   ├── ROADMAP.md      ← dokumen ini
│   ├── BELAJAR.md      ← versi Indonesia (nilai tambah)
│   ├── ARCHITECTURE.md  SECURITY.md  COST.md  RUNBOOK.md
│   ├── DISASTER-RECOVERY.md  TESTING.md
│   ├── adr/            ← 0001-brownfield-import.md, dst.
│   └── images/         ← diagram + screenshot
├── bootstrap/
├── global/             ← budget, OIDC provider, IAM CI role, GuardDuty
├── modules/
│   ├── networking/     ← + flow logs, + tests/, + README (terraform-docs)
│   ├── serverless/     ← FLAGSHIP: pipeline data lengkap
│   ├── data-lake/      ← Glue crawler, Parquet, lifecycle
│   ├── web-app/        ← + HTTPS, autoscaling, ECR, circuit breaker
│   ├── database/       ← + PI, monitoring, KMS
│   ├── observability/  ← BARU: dashboard, alarm, SNS
│   └── eks/            ← + IRSA, addons, logging (opsional; hapus jika tak selesai)
└── environments/
    ├── dev/   ← backend.hcl.example, terraform.tfvars.example
    └── prod/
```

---

## 7. Bahan wawancara

Setiap fase memberi Anda satu cerita siap pakai:

| Fase | Yang bisa Anda katakan |
|---|---|
| 1 | "Saya mengambil alih infra yang dibuat manual ke Terraform pakai `import` block sampai `plan` bersih, tanpa downtime." |
| 2 | "Saya commit lock file dan memakai partial backend config supaya identitas account tidak bocor ke repo." |
| 3 | "CI saya tidak menyimpan satu pun AWS access key — pakai OIDC federation dengan role terpisah untuk plan dan apply." |
| 4 | "Setiap PR menjalankan unit test Terraform yang memverifikasi `deletion_protection` selalu aktif di prod." |
| 5 | "Temuan checkov turun dari 47 ke 3, dan tiga sisanya saya dokumentasikan sebagai accepted risk beserta alasannya." |
| 6 | "Ini URL-nya, silakan dicoba sekarang." |
| 7 | "Saya menulis runbook untuk lima skenario insiden, lengkap dengan alarm yang memicunya." |

---

## 8. Langkah berikutnya

Mulai dari **Fase 0**. Tanpa Terraform terpasang dan kredensial AWS aktif,
tidak ada fase lain yang bisa diverifikasi.

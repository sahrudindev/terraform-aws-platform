# AWS Infrastructure as Code — Terraform

[![terraform plan](https://github.com/sahrudindev/terraform-aws-platform/actions/workflows/terraform-plan.yml/badge.svg)](https://github.com/sahrudindev/terraform-aws-platform/actions/workflows/terraform-plan.yml)
[![security](https://github.com/sahrudindev/terraform-aws-platform/actions/workflows/security.yml/badge.svg)](https://github.com/sahrudindev/terraform-aws-platform/actions/workflows/security.yml)
[![Terraform](https://img.shields.io/badge/terraform-1.16.0-7B42BC)](.terraform-version)
[![AWS Provider](https://img.shields.io/badge/aws%20provider-~%3E%206.0-FF9900)](environments/dev/versions.tf)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

Production-shaped AWS infrastructure managed entirely as code. Two isolated
environments, reusable modules, remote state with native S3 locking, and a CI
pipeline that authenticates to AWS through OIDC federation — no long-lived
access keys anywhere in the repository or in GitHub secrets.

### It ran, and then it was decommissioned

The AWS environment described here was built, verified, and then deliberately
torn down. There is no live endpoint to click any more, and pointing you at a
dead URL would be worse than not having had one.

While it was up, `GET /hello` returned this:

```json
{
  "message": "Provisioned by Terraform, deployed by GitHub Actions over OIDC.",
  "environment": "dev",
  "region": "ap-southeast-1",
  "commit": "3caf5b649772e70c190e659b0017ad32aa1dd1c0",
  "how_this_got_here": [
    "pull request opened",
    "fmt, validate, tflint, terraform test, checkov, trivy, gitleaks",
    "terraform plan posted as a pull request comment",
    "merged to main",
    "apply paused for a human approval",
    "role assumed via OIDC, credentials valid one hour",
    "you are reading the result"
  ]
}
```

That commit is [`3caf5b6`](../../commit/3caf5b649772e70c190e659b0017ad32aa1dd1c0)
in this history, and the [Actions history](../../actions) still holds every run
that produced it — the plan comments, the approval gate, the applies.

The teardown was part of the point. Infrastructure that cannot be removed
cleanly is not under control, and the account this ran in also hosts unrelated
production workloads, so removal had to be provably surgical:

| | |
|---|---|
| Method | `terraform destroy` only — never a console delete, never a name or tag pattern. Destroy can only touch what is in its own state. |
| Before | Every unrelated resource in the account recorded as a baseline |
| Verified | State files checked to contain no identifier belonging to anything else, before anything was destroyed |
| After | Baseline re-checked item by item — every unrelated bucket, instance, database and function untouched |
| Result | 50 resources destroyed across four stacks, 0 unintended |

The procedure is written down in [`docs/TEARDOWN.md`](docs/TEARDOWN.md),
including what keeps billing after a destroy and the three things that refuse to
go quietly.

Rebuilding it is `make bootstrap`, then `terraform apply` in `global` and
`environments/dev`. The quickstart below is the whole of it.

### What is worth looking at

| | Where to check |
|---|---|
| **No long-lived AWS credentials exist.** CI federates through OIDC and holds one-hour credentials. The apply role is pinned to `refs/heads/main` and cannot create users or attach policies to itself. | [`global/github-oidc.tf`](global/github-oidc.tf) · [ADR-0002](docs/adr/0002-ci-iam-permissions.md) |
| **Every pull request gets a `terraform plan` as a comment**, for both environments, before anyone can merge. | [PR #1](../../pull/1) · [`terraform-plan.yml`](.github/workflows/terraform-plan.yml) |
| **It was removed as carefully as it was built** — baseline recorded, state proven clean, every unrelated resource re-checked afterwards. | [`docs/TEARDOWN.md`](docs/TEARDOWN.md) |
| **Applies stop for a human.** The run pauses on a GitHub Environment until a reviewer approves it. | [`terraform-apply.yml`](.github/workflows/terraform-apply.yml) |
| **Module tests need no AWS account.** 18 assertions on mocked providers — including three that prove `prod` is *rejected* without deletion protection, a final snapshot, and 7-day backups. | [`modules/database/tests/`](modules/database/tests/) |
| **checkov: 494 passed, 0 failed, 86 suppressed** — and every suppression carries a written reason in the resource it applies to, not the word "accepted". | [`docs/SECURITY.md`](docs/SECURITY.md) |
| **The teardown is documented too** — what keeps billing, in what order to destroy, and the three things that refuse to go quietly. | [`docs/TEARDOWN.md`](docs/TEARDOWN.md) |

The CI pipeline failed six times before it went green. Each failure and its
cause is in the commit history — a SARIF upload needing GitHub Advanced
Security, trivy silently dropping its severity filter in SARIF mode, and an
OIDC subject claim issued in GitHub's immutable form while the trust policy
matched the classic one. Two of those failures turned out to be real defects in
the infrastructure rather than in the pipeline.

> 🇮🇩 A detailed walkthrough in Bahasa Indonesia, explaining every component and
> how to build the same thing by hand in the AWS Console, lives in
> [`docs/BELAJAR.md`](docs/BELAJAR.md).

---

## Architecture

```mermaid
flowchart TB
    subgraph GH["GitHub"]
        PR["Pull request"] -->|OIDC · read-only role| PLAN["terraform plan<br/>tflint · checkov · trivy"]
        PLAN --> REVIEW["Plan posted as PR comment"]
        REVIEW --> MERGE["Merge to main"]
        MERGE -->|OIDC · apply role<br/>+ required reviewer| APPLY["terraform apply"]
    end

    APPLY --> AWS

    subgraph AWS["AWS account · ap-southeast-1"]
        subgraph STATE["Remote state"]
            S3STATE[("S3 bucket<br/>versioned · encrypted<br/>native lockfile")]
        end

        subgraph GLOBAL["Global"]
            BUDGET["AWS Budgets<br/>+ alerts"]
            OIDC["IAM OIDC provider<br/>+ CI roles"]
        end

        subgraph DEV["dev · VPC 10.10.0.0/16"]
            DNET["public + private subnets<br/>2 AZ · single NAT"]
            DWL["workloads<br/>(feature-flagged)"]
        end

        subgraph PROD["prod · VPC 10.20.0.0/16"]
            PNET["public + private subnets<br/>2 AZ · NAT per AZ"]
            PWL["workloads<br/>multi-AZ · deletion protected"]
        end
    end
```

Each environment composes the same modules with different sizing:

| Module | What it provisions |
|---|---|
| `networking` | VPC, public/private subnets across 2 AZs, IGW, NAT, route tables |
| `web-app` | Application Load Balancer + ECS Fargate service in private subnets |
| `database` | RDS PostgreSQL, private, master password managed by Secrets Manager |
| `serverless` | Lambda + API Gateway HTTP API, source zipped at apply time |
| `eks` | EKS control plane + managed node group |
| `data-lake` | Layered S3 buckets + Glue Data Catalog + Athena workgroup |

---

## Quickstart

Requires [Terraform 1.16.0](.terraform-version) (`use_lockfile` needs ≥ 1.10) and AWS CLI v2.

```bash
# 1. Create the state backend and move its own state into it.
#    Also writes backend.hcl for every other stack.
make bootstrap

# 2. Cost guardrails and CI federation.
cd global
cp terraform.tfvars.example terraform.tfvars   # set alert_emails + github_*
terraform init -backend-config=backend.hcl
terraform apply

# 3. Build the dev foundation.
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform apply
```

After step 1 no Terraform state remains on your machine - the bootstrap stack
stores its own state in the bucket it created. See
[ADR-0005](docs/adr/0005-bootstrapping-the-state-backend.md) for why, and for
the alternatives that were weighed.

Workloads are **off by default**. Enable them one at a time in
`terraform.tfvars` and re-run `plan` before `apply`:

```hcl
enable_nat_gateway = true   # required before anything runs in private subnets
enable_web_app     = true
enable_database    = true
```

---

## CI/CD

| Workflow | Trigger | What it does |
|---|---|---|
| [`terraform-plan.yml`](.github/workflows/terraform-plan.yml) | pull request | `fmt` → `validate` → `tflint` → `plan` for dev and prod, posted as a PR comment; optional Infracost diff |
| [`terraform-apply.yml`](.github/workflows/terraform-apply.yml) | push to `main`, manual dispatch | `apply`, gated behind a GitHub Environment with a required reviewer |
| [`security.yml`](.github/workflows/security.yml) | pull request, push, weekly | checkov, trivy and gitleaks, results uploaded as SARIF to the Security tab |

Authentication uses `sts:AssumeRoleWithWebIdentity`. Two roles with different
blast radius:

- **plan role** — `ReadOnlyAccess` plus state bucket access; assumable from any
  ref in this repository
- **apply role** — `PowerUserAccess` plus a narrowly scoped IAM policy;
  assumable only from `refs/heads/main` and the protected environments

Deliberately *not* `AdministratorAccess` — see
[`docs/adr/0002-ci-iam-permissions.md`](docs/adr/0002-ci-iam-permissions.md).

Repository variables to set once (`Settings → Secrets and variables → Actions → Variables`):

| Variable | Value |
|---|---|
| `AWS_STATE_BUCKET` | output `state_bucket` from `bootstrap` |
| `AWS_PLAN_ROLE_ARN` | output `github_actions_plan_role_arn` from `global` |
| `AWS_APPLY_ROLE_ARN` | output `github_actions_apply_role_arn` from `global` |

---

## Cost

Most of this stack is free or near-free when idle. These are the ones that are not:

| Resource | Cost when idle | Guard |
|---|---|---|
| NAT Gateway | ~$32/month each | `enable_nat_gateway = false` by default; dev shares one NAT |
| EKS control plane | ~$73/month | `enable_eks = false` by default |
| RDS instance | varies by class | `enable_database = false` by default; `db.t4g.micro` in dev |
| ALB | ~$16/month | `enable_web_app = false` by default |
| S3, DynamoDB, Lambda, API Gateway | cents | — |

An AWS Budget with alerts at 80% actual and 100% forecast is created by the
`global` stack before any workload exists.

Disabling GitHub Actions does not stop any of this billing — Actions only drives
the changes. To stop the spend, remove the resources: see
[`docs/TEARDOWN.md`](docs/TEARDOWN.md). `make unplug` revokes CI's access to AWS
without touching infrastructure; `make destroy` removes everything in the order
that works.

---

## Local development

```bash
pre-commit install          # fmt, validate, tflint, terraform-docs, gitleaks
terraform fmt -recursive
tflint --init && tflint --recursive
checkov -d . --config-file .checkov.yaml --compact
```

Conventions:

- `terraform plan` before every `apply`. Never change a managed resource in the Console.
- `.terraform.lock.hcl` **is committed** — CI and every developer resolve identical provider builds.
- `terraform.tfvars` and `backend.hcl` are gitignored; their `*.example` counterparts are not.
- Commits follow [Conventional Commits](https://www.conventionalcommits.org/).

---

## Repository layout

```
bootstrap/              S3 state bucket — run once, state stays local
global/                 account-wide: budgets, GitHub OIDC provider, CI roles
modules/                reusable building blocks
environments/dev/       small, cheap, destroyable
environments/prod/      multi-AZ, deletion protected
docs/                   roadmap, learning guide, ADRs, scan reports
.github/workflows/      plan, apply, security
```

## Documentation

| Document | |
|---|---|
| [`docs/TEARDOWN.md`](docs/TEARDOWN.md) | How to remove all of this, what keeps billing, and what refuses to be deleted |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Request flow, state layout, environment topology, blast radius |
| [`docs/SETUP-AWS-ACCESS.md`](docs/SETUP-AWS-ACCESS.md) | Getting AWS credentials onto a workstation |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Scanning, baseline findings, accepted risks |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Audit findings and the phased plan for this repository |
| [`docs/BELAJAR.md`](docs/BELAJAR.md) | 🇮🇩 Component-by-component walkthrough, Terraform vs Console |
| [`docs/adr/`](docs/adr/) | Architecture Decision Records |
| [`docs/reports/`](docs/reports/) | Security scan baselines |

## License

[MIT](LICENSE)

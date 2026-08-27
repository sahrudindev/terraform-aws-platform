# ADR-0004: Supply the state bucket through partial backend configuration

- **Status:** accepted
- **Date:** 2026-08-27

## Context

The state bucket name is globally unique, which is achieved by appending the AWS
account id: `cloudops-tfstate-<account-id>`. Hardcoding it in `backend.tf`
committed the account id to the repository.

An account id is not a secret and cannot be used to authenticate. It is,
however, an identifier that makes role-ARN enumeration and targeted phishing
easier, and it hardcodes one specific account into code that should be
reusable by anyone.

## Decision

Use Terraform's *partial backend configuration*. `backend.tf` keeps the settings
that are the same for everyone (key, region, encryption, locking); the bucket
name comes from a `backend.hcl` file that is gitignored:

```bash
terraform init -backend-config=backend.hcl
```

`backend.hcl.example` is committed so the shape is obvious. CI writes its own
`backend.hcl` from the `AWS_STATE_BUCKET` repository variable.

## Consequences

- No account identifier in git history going forward.
- `terraform init` now requires a flag. Documented in the README quickstart and
  in every workflow.
- Anyone can clone this repository and point it at their own account by editing
  one line.

## Alternatives considered

- **`TF_BACKEND_*` environment variables** — no such mechanism exists for
  backends; `-backend-config` is the supported path.
- **Leave the account id in place** — it is genuinely low risk, but this
  repository is a portfolio artifact and the reviewer's first question about a
  visible account id is "what else got committed?"

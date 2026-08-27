# ADR-0001: Adopt existing manually-created AWS resources into Terraform

- **Status:** proposed
- **Date:** 2026-08-27

## Context

Part of this AWS account was built by hand in the Console before Terraform was
introduced. Those resources are live and must not be recreated, but they are
invisible to Terraform, so `plan` would try to create duplicates and any manual
change to them is untracked drift.

Two ways to close the gap:

1. Destroy the manual resources and let Terraform rebuild them.
2. Import them into Terraform state so the existing objects become managed.

Option 1 means downtime and data loss. Option 2 is what happens in real
migrations, so that is what this repository does.

## Decision

Adopt existing resources using **`import` blocks** (Terraform ≥ 1.5) rather than
the `terraform import` CLI command.

```hcl
import {
  to = module.networking.aws_vpc.this
  id = "vpc-0abc123def456"
}
```

Where no HCL exists yet for a resource, generate a starting point with:

```bash
terraform plan -generate-config-out=generated.tf
```

then move the generated blocks into the appropriate module by hand and delete
`generated.tf` (it is gitignored).

The import is complete when `terraform plan` reports **no changes** for every
adopted resource. Only then are the `import` blocks removed — at that point the
binding is recorded in state and the blocks are redundant.

## Consequences

- Import blocks are **declarative and reviewable**: they show up in `plan` output
  and go through the normal pull-request flow, unlike the CLI command which
  mutates state directly from someone's laptop with no audit trail.
- The blocks are idempotent, so a partially failed import can simply be re-run.
- Some attributes cannot be read back from the API (for example RDS passwords).
  Those are reconciled by hand and noted here as they are found.
- `plan` output during the transition is noisy and needs careful reading. Every
  proposed change must be understood before applying; an unexplained `destroy`
  during import means the address or the configuration is wrong.

## Alternatives considered

- **`terraform import` CLI** — works, but it is imperative, invisible to code
  review, and easy to run against the wrong workspace.
- **Terraformer / former2** — generate config from live infrastructure
  automatically. Fast, but the output does not match this repository's module
  structure and would have to be rewritten anyway.
- **Start fresh** — rejected: downtime and data loss for no benefit.

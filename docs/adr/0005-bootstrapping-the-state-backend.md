# ADR-0005: Bootstrap the state backend with Terraform, then migrate its own state

- **Status:** accepted
- **Date:** 2026-08-27

## Context

Terraform needs somewhere to keep state before it can manage anything, but the
place it keeps state is itself infrastructure. Something has to create the
bucket first, and that something cannot already be using it.

Four ways this is handled in practice:

| Approach | Where it fits |
|---|---|
| A separate Terraform stack with local state | Most small and mid-size teams |
| CloudFormation or a shell script | Teams that want the circularity gone entirely; CloudFormation stores its own state server-side |
| HCP Terraform / Terraform Cloud | Teams happy to let HashiCorp hold state; free below 500 resources |
| Account vending (Control Tower, Landing Zone Accelerator) | Large organisations, where the backend arrives with the account |

## Decision

Keep the separate `bootstrap/` stack, and close its one real weakness by
**migrating the bootstrap stack's own state into the bucket it just created**.

`make bootstrap` runs the whole sequence:

1. `terraform init` with no backend, `terraform apply` - the bucket is created,
   state is local
2. The bucket name is written into `backend.hcl` for every stack
3. `backend.tf.tpl` is copied to `backend.tf` and
   `terraform init -migrate-state` uploads the local state into the bucket,
   after which the local state files are deleted

The DynamoDB lock table is gone; `use_lockfile` replaced it (see
[ADR-0003](0003-s3-native-state-locking.md)). The bucket carries
`prevent_destroy`.

## Consequences

- **No Terraform state exists on any laptop.** The original weakness of the
  bootstrap pattern - a state file that lives on one machine and is gitignored,
  so losing the machine orphans the backend - is gone.
- The bucket is genuinely circular: it stores the state that describes it. This
  is safe because the resource is create-once and effectively immutable, and
  because `prevent_destroy` blocks the one dangerous operation.
- Tearing the backend down is deliberately awkward: `prevent_destroy` must be
  removed by hand first. That is the intent.
- The approach is re-runnable. `make bootstrap` detects an existing `backend.tf`
  and simply applies against remote state.

## Alternatives considered

- **CloudFormation for the backend** - removes the circularity outright and is
  what several teams do. Rejected because it puts a second IaC language in a
  repository whose subject is Terraform, for one stack of six resources.
- **HCP Terraform** - genuinely good, free at this size, and would delete this
  problem along with the whole `bootstrap/` directory. Rejected for a specific
  reason: this repository exists to demonstrate the ability to *build* a state
  backend correctly - versioning, encryption, TLS-only access, lifecycle,
  locking, blast radius. Outsourcing it would hide exactly the knowledge an
  interviewer probes for. Worth revisiting the day the goal stops being
  demonstration.
- **Leaving bootstrap state local** - the common tutorial ending. It works right
  up until the laptop does not.

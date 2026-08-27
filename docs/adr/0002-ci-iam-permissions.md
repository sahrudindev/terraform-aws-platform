# ADR-0002: Scope the CI apply role below AdministratorAccess

- **Status:** accepted
- **Date:** 2026-08-27

## Context

The GitHub Actions apply role needs to create every resource in this repository:
VPCs, ECS services, RDS instances, Lambda functions, EKS clusters, S3 buckets,
and the IAM roles those services assume.

The path of least resistance is to attach `AdministratorAccess`. Nearly every
tutorial does this. It also means that anyone who can get a workflow to run on
`main` has full control of the account, including the ability to rewrite the
trust policy that was supposed to contain them.

## Decision

The apply role gets:

- `PowerUserAccess` — every service action, but **no IAM**
- A scoped inline policy granting only the IAM actions this repository actually
  needs (create/update roles, policies, instance profiles, OIDC providers)
- `iam:PassRole` constrained by `iam:PassedToService`, so a role can only be
  handed to the AWS services listed there, not to an arbitrary principal

The plan role gets `ReadOnlyAccess` plus read/write on the state bucket, and
nothing else.

Both roles are assumable only through OIDC federation, and the apply role's
trust policy additionally pins the subject to `refs/heads/main` and the
protected GitHub Environments.

## Consequences

- A compromised workflow cannot create an admin user, attach
  `AdministratorAccess` to itself, or pass a privileged role to a service that
  would run attacker code.
- Adding a new AWS service to this repository may fail on a missing IAM action.
  That is the intended cost: the failure is explicit, and the fix is one
  reviewed line in `global/github-oidc.tf`.
- `PowerUserAccess` is still broad. It is a deliberate middle point, not an
  end state; narrowing it further requires knowing the exact action set, which
  is best derived from CloudTrail once the pipeline has run for a while.

## Alternatives considered

- **`AdministratorAccess`** — rejected. Convenient, and removes the entire point
  of scoping the trust policy.
- **A fully hand-written least-privilege policy** — the correct end state, but
  guessing the action set up front produces a policy that is both incomplete and
  falsely reassuring. Revisit with CloudTrail data.
- **Separate roles per environment** — worth doing once `prod` holds anything
  real. Tracked as future work.

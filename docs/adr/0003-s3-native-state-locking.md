# ADR-0003: Use S3 native state locking instead of DynamoDB

- **Status:** accepted
- **Date:** 2026-08-27

## Context

The original backend used the long-standing pattern of an S3 bucket for state
plus a DynamoDB table for locking, because S3 historically had no way to prevent
two concurrent writers from clobbering each other's state.

S3 has supported conditional writes since late 2024, and Terraform 1.10
introduced `use_lockfile`, which uses them to hold a lock object next to the
state file. The `dynamodb_table` backend argument is deprecated.

## Decision

Set `use_lockfile = true` on the S3 backend and drop `dynamodb_table`.

## Consequences

- One less resource to provision, tag, monitor and pay for.
- The lock lives beside the state, so both are covered by the same bucket
  policy, encryption and versioning settings.
- Requires Terraform ≥ 1.10 for everyone and in CI. Pinned in
  `.terraform-version` and enforced by `required_version = ">= 1.10"`.
- The DynamoDB table has been removed from `bootstrap` entirely. Nothing had
  been applied yet when the switch was made, so there was no older state to
  strand and no transition period to manage.

## Alternatives considered

- **Keep DynamoDB** — works, but carries a deprecated argument into a repository
  whose whole purpose is to demonstrate current practice.
- **No locking** — never acceptable with more than one writer, and CI counts as
  a second writer.

# Security posture

Every pull request runs [checkov](https://www.checkov.io/),
[trivy](https://trivy.dev/) and [gitleaks](https://gitleaks.io/). Results are
uploaded as SARIF and appear in the repository's Security tab.

Two misconfiguration scanners rather than one, because their rule sets do not
overlap completely. trivy caught the state bucket using SSE-S3 after checkov had
already passed on it — see below. Accepted findings are recorded in both places:
inline `#checkov:skip` comments in the resource, and `.trivyignore.yaml` with
the same reasoning.

## Where it stands

| Date | Passed | Failed | Suppressed | Report |
|---|---|---|---|---|
| 2026-08-27 (baseline) | 244 | 74 | 0 | [baseline](reports/checkov-baseline-2026-08-27.txt) |
| 2026-08-27 (hardening pass) | 425 | 52 | 2 | [after](reports/checkov-2026-08-27-after-hardening.txt) |
| 2026-08-27 (suppressions documented) | **445** | **0** | **86** | [final](reports/checkov-2026-08-27-final.txt) |

Read the third row carefully, because the shape of it matters more than the
zero. Going from 52 failures to none was not 52 fixes. Two were real defects
and were fixed; the rest are findings this project accepts, and each one now
carries a written reason in the Terraform file itself.

86 suppressions on 24 distinct checks - most checks fire once per module and
again per environment that instantiates it.

### What was actually fixed in the hardening pass

VPC flow logs · a customer-managed KMS key per environment covering log groups,
buckets and RDS storage · S3 versioning and lifecycle rules · TLS-only bucket
policies · the VPC default security group emptied · security group egress
narrowed from `0.0.0.0/0` to the VPC CIDR and to 443 · ALB access logs and
deletion protection · ECS deployment circuit breaker and auto scaling · Lambda
X-Ray tracing and a dead-letter queue · RDS Performance Insights and enhanced
monitoring under CMK · EKS control-plane logging, envelope encryption for
Secrets, IRSA and managed addons · Kubernetes moved off extended support (1.31)
onto 1.35.

Two defects surfaced by the scanner and fixed rather than suppressed:

- lifecycle rules for the raw and query-result buckets, and for the ALB log
  bucket, had no `abort_incomplete_multipart_upload`, so a failed upload would
  have billed indefinitely
- the data-lake and EKS keys had no explicit key policy
- the state bucket used SSE-S3. This was first suppressed on the grounds that a
  CMK would have to exist before the bucket holding the state that describes it.
  That reasoning was wrong - both are created in the same apply, and nothing
  reads state until after they exist. trivy flagged it independently of checkov,
  which is the argument for running two scanners with different rule sets. The
  bucket now uses a rotating CMK with an explicit key policy, and the CI roles
  are granted `kms:Decrypt` on it, because bucket permissions alone stop working
  the moment the objects are KMS-encrypted

One structural fix is worth calling out: the data-lake module iterated with
`for_each = aws_s3_bucket.this`, which checkov cannot resolve statically, so a
dozen controls reported as failing on resources that were correctly configured.
Iterating over the static `local.buckets` map made the graph analysable - and
made the code easier to read.

## Accepted risks

Findings that are deliberately not fixed are suppressed **inline in the
Terraform resource**, so the reason travels with the code and shows up in
review. Every suppression names a specific trade-off; none of them say
"accepted" and stop there.

```hcl
#checkov:skip=CKV_AWS_144:Cross-region replication triples storage cost and this
#                          bucket holds reproducible data. Revisit if it ever
#                          holds the only copy of anything.
```

They fall into five groups:

| Group | Checks | Why |
|---|---|---|
| **Needs a domain** | `CKV_AWS_2` `CKV_AWS_103` `CKV_AWS_378` `CKV2_AWS_20` `CKV2_AWS_28` | HTTPS, the HTTP→HTTPS redirect, a TLS policy and WAF all start with an ACM certificate, which starts with a domain this project does not own. These become real findings the day one is attached. |
| **Cost, not security** | `CKV_AWS_144` `CKV_AWS_338` `CKV2_AWS_28` | Cross-region replication triples storage cost; one-year log retention buys nothing for logs read within days of an incident. |
| **The check does not fit the resource** | `CKV_AWS_356` `CKV_AWS_109` `CKV_AWS_111` `CKV_AWS_260` `CKV_AWS_378` | `kms:*` on `"*"` inside a *key policy* means that one key, not every key — AWS requires it or the key cannot be granted through IAM at all. A public load balancer accepting HTTP from the internet is its job. |
| **Environment-dependent, enforced elsewhere** | `CKV_AWS_157` `CKV_AWS_293` `CKV_AWS_150` `CKV_AWS_39` `CKV_AWS_38` | Multi-AZ, deletion protection and a private EKS endpoint default to the safe value; only `dev` opts out, and the lifecycle preconditions in `modules/database` make `prod` impossible to apply without them. The scanner reads the dev call site. |
| **Static analysis limitation** | `CKV2_AWS_6` `CKV_AWS_21` `CKV2_AWS_61` | The ALB log bucket does have a public access block, versioning and a lifecycle rule. They sit behind `count`, which the graph does not resolve. |

A finding is only suppressed when there is a written reason a reviewer would
accept. None were suppressed to make the build green — the two that could be
fixed, were.

## Credentials

- No AWS access keys exist in this repository, in GitHub secrets, or in CI.
  GitHub Actions authenticates with OIDC federation and receives credentials
  that expire in one hour. See
  [`adr/0002-ci-iam-permissions.md`](adr/0002-ci-iam-permissions.md).
- The RDS master password is generated and rotated by AWS Secrets Manager
  (`manage_master_user_password = true`). It never exists in Terraform
  configuration, and the state file holds only the secret's ARN.
- `terraform.tfvars`, `backend.hcl` and `*.tfstate` are gitignored. gitleaks
  runs over the full history on every push.

## Reporting

This is a portfolio repository and holds no production data. If you find
something anyway, open an issue.

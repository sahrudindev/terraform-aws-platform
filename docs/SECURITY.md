# Security posture

Every pull request runs [checkov](https://www.checkov.io/),
[trivy](https://trivy.dev/) and [gitleaks](https://gitleaks.io/). Results are
uploaded as SARIF and appear in the repository's Security tab.

## Baseline

The first full scan of this repository, before any hardening work:

| Date | Passed | Failed | Skipped | Report |
|---|---|---|---|---|
| 2026-08-27 (baseline) | 244 | 74 | 0 | [baseline](reports/checkov-baseline-2026-08-27.txt) |
| 2026-08-27 (after first hardening pass) | **425** | **52** | 2 | [after](reports/checkov-2026-08-27-after-hardening.txt) |

Closed in the first pass: VPC flow logs, a customer-managed KMS key per
environment covering log groups, buckets and RDS storage, S3 versioning and
lifecycle rules, TLS-only bucket policies, the VPC default security group
emptied, narrowed security group egress, ALB access logs and deletion
protection, ECS deployment circuit breaker and auto scaling, Lambda X-Ray
tracing and a dead-letter queue, RDS Performance Insights and enhanced
monitoring with CMK encryption, EKS control-plane logging and envelope
encryption for Secrets, IRSA, managed addons, and the Kubernetes version moved
off extended support (1.31) onto 1.35.

One structural fix is worth calling out: the data-lake module iterated with
`for_each = aws_s3_bucket.this`, which checkov cannot resolve statically, so a
dozen controls reported as failing on resources that were in fact configured.
Iterating over the static `local.buckets` map instead made the graph
analysable - and made the code easier to read for humans too.

This table is updated as findings are closed, so the delta is visible rather
than asserted.

## What the baseline is made of

| Theme | Checks | Plan |
|---|---|---|
| S3 buckets lack KMS CMK encryption, versioning, lifecycle, replication, access logging | `CKV_AWS_18` `CKV_AWS_21` `CKV_AWS_144` `CKV_AWS_145` `CKV2_AWS_61` `CKV2_AWS_62` | Introduce a customer-managed KMS key with rotation; add versioning and lifecycle rules to the data-lake buckets. Cross-region replication is likely to be accepted rather than implemented — see below. |
| ALB serves plaintext HTTP, no access logs, no WAF, no deletion protection | `CKV_AWS_2` `CKV_AWS_91` `CKV_AWS_103` `CKV_AWS_131` `CKV2_AWS_20` `CKV2_AWS_28` | Add an ACM certificate, an HTTPS listener, an HTTP→HTTPS redirect, access logging and WAFv2 managed rule groups. Requires a domain name. |
| Security groups allow unrestricted egress | `CKV_AWS_382` | Narrow egress to the ports each tier actually needs, starting with `prod`. |
| No VPC flow logs | `CKV_AWS_11` family | Ship flow logs to CloudWatch Logs. |
| RDS lacks Performance Insights, enhanced monitoring, log exports, IAM auth | `CKV_AWS_118` `CKV_AWS_129` `CKV_AWS_293` `CKV_AWS_353` | Enable all four. |
| Lambda lacks X-Ray tracing, a DLQ and code signing | `CKV_AWS_50` `CKV_AWS_116` `CKV_AWS_272` | Enable tracing and add an SQS dead-letter queue. Code signing is out of scope for this repository. |
| EKS lacks control-plane logging, secrets encryption, and restricts nothing on the public endpoint | `CKV_AWS_37` `CKV_AWS_38` `CKV_AWS_39` `CKV_AWS_58` | Enable all cluster log types, add KMS envelope encryption for secrets, make the endpoint private with a CIDR allow-list. |
| CloudWatch log groups are not KMS-encrypted and retain for 14 days | `CKV_AWS_158` `CKV_AWS_338` | Encrypt with the shared CMK. The 1-year retention the check wants is a cost decision, not a security one. |
| API Gateway has no access logging, no WAF, no client certificate | `CKV_AWS_76` `CKV_AWS_378` `CKV2_AWS_29` | Add access logging. WAF and mTLS depend on how the API is exposed. |

## Accepted risks

Findings that are deliberately not fixed are suppressed **inline in the
Terraform file**, so the reason travels with the code and shows up in review:

```hcl
#checkov:skip=CKV_AWS_144:Cross-region replication triples storage cost and this
#                          bucket holds reproducible data. Revisit if it ever
#                          holds the only copy of anything.
```

The suppression list is intentionally short. A finding is only suppressed when
there is a written reason a reviewer would accept — never to make the build
green.

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

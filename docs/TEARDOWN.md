# Tearing this down

Disabling GitHub Actions does not stop anything from billing. Actions is the
driver; the resources are in AWS and keep running whether or not anything
drives them. Turning it off only prevents new changes.

This document is the other half of the README. Infrastructure that cannot be
removed cleanly is not really under control.

## What actually costs money

Most of what this repository creates is free. These are the exceptions:

| Resource | Cost when idle | Where |
|---|---|---|
| KMS customer-managed key | ~$1/month each | `bootstrap` (state), one per environment |
| NAT Gateway | ~$32/month each | `networking`, off unless `enable_nat_gateway` |
| EKS control plane | ~$73/month | `eks`, off unless `enable_eks` |
| Application Load Balancer | ~$16/month | `web-app`, off unless `enable_web_app` |
| RDS instance | varies by class | `database`, off unless `enable_database` |
| CloudWatch Logs, S3 storage | cents | flow logs, state, data lake |
| VPC, subnets, route tables, IGW, security groups | **free** | `networking` |

With every workload flag off — the default — the running cost is the KMS keys
and a few cents of storage.

To see what is actually live:

```bash
aws resourcegroupstaggingapi get-resources --region ap-southeast-1 \
  --tag-filters Key=Project,Values=cloudops \
  --query 'ResourceTagMappingList[].ResourceARN' --output text
```

## Pulling the plug without deleting anything

If the goal is only to stop CI from being able to reach AWS, destroy the
`global` stack. It holds the OIDC provider and both CI roles, and nothing else
depends on it:

```bash
cd global && terraform destroy
```

GitHub immediately loses every route into the account. The infrastructure keeps
running, and re-applying `global` restores access.

## Full teardown

Order matters. `bootstrap` holds the state for every other stack, so it goes
last — destroying it first orphans everything else and leaves you deleting
resources by hand in the console.

```bash
# 1. Workloads and networking
cd environments/dev  && terraform destroy
cd ../prod           && terraform destroy

# 2. Account-wide: budget, OIDC provider, CI roles
cd ../../global      && terraform destroy

# 3. State backend, last
cd ../bootstrap      && terraform destroy
```

Or `make destroy`, which runs the same sequence and stops at the first failure.

## Three things that will not go quietly

### The state bucket refuses to be destroyed

`bootstrap/main.tf` carries `prevent_destroy = true` on the bucket. Terraform
will refuse, by design — deleting it deletes the record of everything else.
Remove the block deliberately:

```hcl
resource "aws_s3_bucket" "state" {
  lifecycle {
    prevent_destroy = false   # was true
  }
}
```

That edit is meant to be a moment to stop and think, not an obstacle.

### KMS keys keep billing for 30 days

A destroyed key enters `PendingDeletion` rather than disappearing, and **still
costs ~$1/month** for the whole window. That window exists for a reason: losing
the state key makes every state file unreadable, and `aws kms
cancel-key-deletion` is the way back.

```bash
aws kms describe-key --key-id <id> --query 'KeyMetadata.{state:KeyState,deletes:DeletionDate}'
aws kms cancel-key-deletion --key-id <id>   # within the window
```

To shorten it, lower `deletion_window_in_days` before destroying. Seven days is
the minimum AWS allows.

### Versioned buckets are not empty when they look empty

`terraform destroy` fails on a bucket that still holds objects, and versioning
means deleted objects are still there as noncurrent versions. The data-lake
buckets take `force_destroy` (true in dev, false in prod). The state bucket does
not, so empty it by hand:

```bash
aws s3api delete-objects --bucket "$BUCKET" \
  --delete "$(aws s3api list-object-versions --bucket "$BUCKET" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)"
```

Repeat for `DeleteMarkers`.

## GitHub side

None of this costs anything, but leaving it behind leaves credentials pointing
at an account that may no longer be yours:

- **Repository variables** — `AWS_STATE_BUCKET`, `AWS_PLAN_ROLE_ARN`,
  `AWS_APPLY_ROLE_ARN`. Not secrets, but they name the account.
- **Environments** — `dev` and `prod`, with their protection rules.
- **The OIDC provider** in AWS is removed by `terraform destroy` in `global`.

```bash
gh variable delete AWS_STATE_BUCKET
gh variable delete AWS_PLAN_ROLE_ARN
gh variable delete AWS_APPLY_ROLE_ARN
gh api -X DELETE repos/<owner>/<repo>/environments/dev
gh api -X DELETE repos/<owner>/<repo>/environments/prod
```

## Verifying it is gone

```bash
# No tagged resources remain
aws resourcegroupstaggingapi get-resources --region ap-southeast-1 \
  --tag-filters Key=Project,Values=cloudops --query 'length(ResourceTagMappingList)'

# No keys left pending
aws kms list-aliases --query "Aliases[?starts_with(AliasName,'alias/cloudops')]"

# Nothing charging next month
aws ce get-cost-and-usage --region us-east-1 \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY --metrics UnblendedCost \
  --filter '{"Tags":{"Key":"Project","Values":["cloudops"]}}'
```

The last one reports zero only after the cost allocation tag has been active
long enough to have data, and only for spend incurred after activation.

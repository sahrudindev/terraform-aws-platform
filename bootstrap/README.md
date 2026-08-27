# `bootstrap`

Creates the S3 bucket that holds Terraform state for every other stack, then
moves its own state into that bucket.

Run once:

```bash
make bootstrap        # from the repository root
```

That does three things:

1. `terraform apply` with local state — creates the bucket
2. Writes `backend.hcl` into `bootstrap/`, `global/`, `environments/dev/` and
   `environments/prod/` using the bucket name it just produced
3. Copies `backend.tf.tpl` to `backend.tf` and runs
   `terraform init -migrate-state`, then deletes the local state files

Re-running it is safe: it detects an existing `backend.tf` and simply applies
against remote state.

## What gets created

| Resource | Why |
|---|---|
| `aws_s3_bucket` | Holds every stack's state. Carries `prevent_destroy`. |
| `aws_s3_bucket_versioning` | Every state write keeps a previous version, so a corrupted state can be rolled back |
| `aws_s3_bucket_server_side_encryption_configuration` | State contains endpoints, ARNs and occasionally secrets |
| `aws_s3_bucket_public_access_block` | Closes all four public-access paths |
| `aws_s3_bucket_lifecycle_configuration` | Expires superseded state versions after 90 days |
| `aws_s3_bucket_policy` | Denies any request where `aws:SecureTransport` is false |

There is no DynamoDB table. Locking uses S3 conditional writes via
`use_lockfile` — see [ADR-0003](../docs/adr/0003-s3-native-state-locking.md).

## Verifying it worked

```bash
# The bucket exists, with versioning and encryption on
aws s3api get-bucket-versioning --bucket "$(terraform output -raw state_bucket)"
aws s3api get-bucket-encryption  --bucket "$(terraform output -raw state_bucket)"

# State objects are landing in it
aws s3 ls "s3://$(terraform output -raw state_bucket)/" --recursive

# Nothing is left on this machine
ls bootstrap/terraform.tfstate   # should say: No such file or directory
```

In the AWS Console: **S3 → Buckets → `cloudops-tfstate-<account-id>`**. State
files appear under `bootstrap/`, `global/`, `dev/` and `prod/` prefixes as each
stack is applied.

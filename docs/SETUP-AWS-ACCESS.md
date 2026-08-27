# Getting AWS credentials onto a workstation

Terraform never receives credentials directly. It reads whatever the AWS SDK
resolves, in this order:

1. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN` env vars
2. The profile named by `AWS_PROFILE`, otherwise `default`, in `~/.aws/config`
   and `~/.aws/credentials`
3. Instance/container/EKS roles when running on AWS

So "connecting Terraform to AWS" means: make `aws sts get-caller-identity`
succeed. Nothing in this repository needs to change.

## Option A — IAM Identity Center (recommended)

Credentials are short-lived and refreshed by `aws sso login`. Nothing
long-lived is written to disk.

1. In the AWS Console, open **IAM Identity Center**, enable it, and note the
   start URL (`https://d-xxxxxxxxxx.awsapps.com/start`).
2. Create a user, and a permission set (`AdministratorAccess` while
   bootstrapping this repository).
3. Assign the user to the account with that permission set.
4. On the workstation:

   ```bash
   aws configure sso
   # SSO start URL      : https://d-xxxxxxxxxx.awsapps.com/start
   # SSO region         : ap-southeast-1
   # CLI default region : ap-southeast-1
   # Profile name       : cloudops
   ```

5. Use it:

   ```bash
   export AWS_PROFILE=cloudops
   aws sso login
   aws sts get-caller-identity
   ```

Sessions expire; re-run `aws sso login` when they do.

## Option B — IAM user with an access key

Simpler, but the key is long-lived and sits in `~/.aws/credentials` in plain
text. Acceptable for a personal account, not for anything shared.

1. **IAM → Users → Create user**, name it `terraform-cli`. Do *not* give it
   console access.
2. Attach `AdministratorAccess` while bootstrapping.
3. **Security credentials → Create access key → Command Line Interface (CLI)**.
4. On the workstation, run `aws configure` and paste the key when prompted.
   The secret is shown once; if it is lost, delete the key and make a new one.
5. Enable MFA on the user, and on the account root user.

## Guardrails, whichever option you pick

- The **root user** is for billing and account settings only. Give it MFA and
  then leave it alone.
- Rotate or delete access keys that are no longer used
  (`aws iam list-access-keys --user-name terraform-cli`).
- `AdministratorAccess` is for bootstrapping. Once `global` has been applied,
  day-to-day work can move to a narrower role.
- CI never uses any of this. GitHub Actions federates through OIDC and holds no
  key at all — see [`adr/0002-ci-iam-permissions.md`](adr/0002-ci-iam-permissions.md).

## Verifying

```bash
aws sts get-caller-identity
# { "UserId": "...", "Account": "123456789012", "Arn": "arn:aws:iam::..." }

aws configure list          # which profile and source is in effect
aws s3 ls                   # does the identity actually have permissions
```

Once that works:

```bash
cd environments/dev
terraform init -backend-config=backend.hcl
terraform plan
```

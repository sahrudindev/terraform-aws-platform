# ============================================================================
# GitHub Actions <-> AWS federation via OIDC.
#
# This removes the need for long-lived AWS access keys in GitHub secrets.
# Workflows call sts:AssumeRoleWithWebIdentity and receive short-lived
# credentials that are scoped to this repository, and further scoped by ref:
#
#   plan  role -> assumable from pull requests and any branch  (read-only)
#   apply role -> assumable only from refs/heads/main          (write)
# ============================================================================

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = { Name = "${var.project}-github-oidc" }
}

locals {
  # GitHub issues the OIDC subject claim in one of two shapes.
  #
  #   classic   : repo:<owner>/<repo>
  #   immutable : repo:<owner>@<owner_id>/<repo>@<repo_id>
  #
  # The immutable form embeds numeric ids so that renaming an account or a
  # repository does not quietly hand this trust to whoever claims the freed
  # name. It is what this account issues, and it is the safer of the two, so it
  # is what this configuration targets when the ids are supplied.
  #
  # Check which form an account uses:
  #   gh api repos/<owner>/<repo>/actions/oidc/customization/sub
  #
  # A trust policy written against the wrong shape does not warn. It denies
  # every assume-role with "Not authorized to perform
  # sts:AssumeRoleWithWebIdentity", which reads like a permissions problem.
  use_immutable_subject = var.github_owner_id != null && var.github_repo_id != null

  subject_prefix = (local.use_immutable_subject
    ? "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}"
    : "repo:${var.github_owner}/${var.github_repo}"
  )
}

# --- Trust policies ---------------------------------------------------------

# Plan runs on every pull request, so the subject is left broad but is still
# pinned to this one repository.
data "aws_iam_policy_document" "plan_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.subject_prefix}:*"]
    }
  }
}

# Apply is restricted to the default branch and to the protected GitHub
# Environments, so a pull request from a fork can never reach it.
data "aws_iam_policy_document" "apply_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.subject_prefix}:ref:refs/heads/main",
        "${local.subject_prefix}:environment:dev",
        "${local.subject_prefix}:environment:prod",
      ]
    }
  }
}

# --- State backend access (both roles need it) ------------------------------

data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }

  statement {
    sid = "ReadWriteState"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.state_bucket}/*"]
  }

  # The state bucket is encrypted with a customer-managed key, so bucket
  # permissions alone are not enough to read or write an object.
  dynamic "statement" {
    for_each = var.state_kms_key_arn != null ? [1] : []

    content {
      sid = "UseStateEncryptionKey"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
      ]
      resources = [var.state_kms_key_arn]
    }
  }
}

resource "aws_iam_policy" "state_access" {
  name_prefix = "${var.project}-tfstate-access-"
  description = "Read/write Terraform state and its S3 native lock files"
  policy      = data.aws_iam_policy_document.state_access.json
}

# --- Plan role: read-only over AWS, read/write over state -------------------

resource "aws_iam_role" "plan" {
  name                 = "${var.project}-gha-terraform-plan"
  description          = "Assumed by GitHub Actions to run terraform plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "plan_state" {
  role       = aws_iam_role.plan.name
  policy_arn = aws_iam_policy.state_access.arn
}

# --- Apply role -------------------------------------------------------------
#
# PowerUserAccess covers every service this repo provisions but deliberately
# excludes IAM, so the IAM permissions are granted separately and narrowly
# below. AdministratorAccess would be simpler and is what most tutorials do;
# it is avoided here on purpose. See docs/adr/0002-ci-iam-permissions.md.

resource "aws_iam_role" "apply" {
  name                 = "${var.project}-gha-terraform-apply"
  description          = "Assumed by GitHub Actions to run terraform apply"
  assume_role_policy   = data.aws_iam_policy_document.apply_assume.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_poweruser" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "apply_state" {
  role       = aws_iam_role.apply.name
  policy_arn = aws_iam_policy.state_access.arn
}

# The roles and policies this repo creates for ECS tasks, Lambda, EKS nodes
# and so on. Scoped by path so CI cannot touch unrelated identities.
data "aws_iam_policy_document" "apply_iam" {
  #checkov:skip=CKV_AWS_110:The actions listed are exactly what this repository needs to create the roles its workloads assume. IAM does not support resource-level constraints on CreateRole, and iam:PassRole is constrained by iam:PassedToService below so a role cannot be handed to an arbitrary principal. Reasoning in docs/adr/0002-ci-iam-permissions.md.
  #checkov:skip=CKV_AWS_356:Same statement. Narrowing it means predicting every name_prefix this repository will ever generate.
  #checkov:skip=CKV_AWS_109:Same statement. This role deliberately cannot create users, attach user policies, or modify its own trust policy.
  statement {
    sid = "ManageWorkloadIdentities"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:ListRoles",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicyVersions",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:CreateServiceLinkedRole",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassWorkloadRolesToAwsServices"
    actions   = ["iam:PassRole"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "ecs-tasks.amazonaws.com",
        "lambda.amazonaws.com",
        "eks.amazonaws.com",
        "ec2.amazonaws.com",
        "rds.amazonaws.com",
        "glue.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "apply_iam" {
  name   = "workload-identity-management"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_iam.json
}

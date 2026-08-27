# Architecture

## How a change reaches AWS

Nothing is applied from a laptop. A change is a pull request, and the only
path to production runs through review, automated checks, and a human approval.

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Engineer
    participant GH as GitHub
    participant CI as Actions runner
    participant STS as AWS STS
    participant AWS as AWS account

    Dev->>GH: open pull request
    GH->>CI: trigger plan workflow
    CI->>CI: fmt · validate · tflint · terraform test
    Note over CI: tests run on mocked providers<br/>no credentials, no cost
    CI->>STS: AssumeRoleWithWebIdentity (plan role)
    STS-->>CI: credentials, 1 hour, read-only
    CI->>AWS: terraform plan
    AWS-->>CI: proposed changes
    CI->>GH: post plan as PR comment
    Dev->>GH: review plan, merge
    GH->>CI: trigger apply workflow
    CI->>GH: pause for required reviewer
    GH-->>CI: approved
    CI->>STS: AssumeRoleWithWebIdentity (apply role)
    Note over STS: subject pinned to refs/heads/main
    STS-->>CI: credentials, 1 hour, write
    CI->>AWS: terraform apply
```

No long-lived AWS access key exists anywhere in this flow.

## State

```mermaid
flowchart LR
    subgraph LOCAL["Step 1 · local state"]
        B1["bootstrap<br/>terraform apply"]
    end

    subgraph S3["S3 bucket · versioned · encrypted · TLS-only · prevent_destroy"]
        K1["bootstrap/terraform.tfstate"]
        K2["global/terraform.tfstate"]
        K3["dev/terraform.tfstate"]
        K4["prod/terraform.tfstate"]
        LOCK["*.tflock<br/>S3 conditional write"]
    end

    B1 -->|creates| S3
    B1 -->|"Step 2 · init -migrate-state"| K1

    G["global stack"] --> K2
    D["dev stack"] --> K3
    P["prod stack"] --> K4

    K2 -.->|guarded by| LOCK
    K3 -.->|guarded by| LOCK
    K4 -.->|guarded by| LOCK
```

The bootstrap stack stores its own state in the bucket it created. After step 2
no Terraform state remains on any workstation. Locking uses S3 conditional
writes rather than a DynamoDB table — see
[ADR-0003](adr/0003-s3-native-state-locking.md) and
[ADR-0005](adr/0005-bootstrapping-the-state-backend.md).

## Environment topology

`dev` and `prod` are the same modules with different arguments. They share no
state, no VPC, and no CIDR range.

```mermaid
flowchart TB
    subgraph ACC["AWS account · ap-southeast-1"]
        subgraph GL["global"]
            BUD["AWS Budgets<br/>80% actual · 100% forecast"]
            OIDC["IAM OIDC provider"]
            RP["gha-terraform-plan<br/>ReadOnlyAccess"]
            RA["gha-terraform-apply<br/>PowerUser + scoped IAM"]
        end

        subgraph DEV["dev · 10.10.0.0/16"]
            direction TB
            DK["KMS CMK<br/>rotating"]
            DV["VPC · 2 AZ<br/>1 shared NAT<br/>flow logs"]
            DW["workloads<br/>all flags off"]
            DK -.->|encrypts| DV
            DV --> DW
        end

        subgraph PRD["prod · 10.20.0.0/16"]
            direction TB
            PK["KMS CMK<br/>rotating"]
            PV["VPC · 2 AZ<br/>NAT per AZ<br/>flow logs"]
            PW["workloads<br/>multi-AZ<br/>deletion protected"]
            PK -.->|encrypts| PV
            PV --> PW
        end
    end
```

## Inside an environment

Every workload is behind a feature flag and off by default, because the
expensive resources here bill whether or not anyone uses them.

```mermaid
flowchart TB
    NET["<b>networking</b><br/>VPC · subnets · IGW · NAT · flow logs"]
    KMS["<b>kms</b><br/>one CMK, rotating<br/>explicit key policy"]

    KMS -.-> NET
    KMS -.-> WEB
    KMS -.-> DB
    KMS -.-> SRV
    KMS -.-> LAKE
    KMS -.-> EKS

    NET --> WEB["<b>web-app</b><br/>ALB → ECS Fargate<br/>autoscaling · circuit breaker"]
    NET --> DB["<b>database</b><br/>RDS PostgreSQL<br/>Secrets Manager · PI"]
    NET --> EKS["<b>eks</b><br/>control plane · node group<br/>IRSA · addons"]

    SRV["<b>serverless</b><br/>API Gateway → Lambda<br/>X-Ray · DLQ"]
    LAKE["<b>data-lake</b><br/>S3 raw/processed/results<br/>Glue · Athena"]

    WEB -->|"SG → SG, port 5432"| DB

    classDef off stroke-dasharray: 4 3
    class WEB,DB,EKS,SRV,LAKE off
```

Dashed borders are flag-controlled. `networking` and `kms` are always on.

## Blast radius

What can reach what, and what stops it.

| Boundary | Enforced by |
|---|---|
| Pull request cannot write to AWS | Plan role holds `ReadOnlyAccess`; trust policy grants write only to `refs/heads/main` |
| CI cannot escalate its own privileges | Apply role has no `iam:CreateUser`, no `iam:AttachUserPolicy`; `iam:PassRole` is constrained by `iam:PassedToService` |
| `dev` cannot damage `prod` | Separate state keys, separate VPCs, non-overlapping CIDRs |
| `prod` cannot be applied unsafely | Lifecycle preconditions reject prod without deletion protection, a final snapshot, and 7-day backups |
| A stray `destroy` cannot remove the state bucket | `prevent_destroy` on the bucket |
| The database cannot be reached from the internet | Private subnets, `publicly_accessible = false`, ingress only from a named security group |
| The VPC default security group cannot be used as a bypass | Emptied of all rules by `aws_default_security_group` |
| State cannot be read over plaintext HTTP | Bucket policy denies `aws:SecureTransport = false` |

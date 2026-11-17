# AWS Security Audit

A sample AWS security audit: scan a live account and its infrastructure code,
rank every finding by severity, fix the important ones and prove the fixes with
a second scan.

The target is my own working stack,
[AwsEcsFoundationTerraform](https://github.com/joheee/AwsEcsFoundationTerraform)
(VPC, ECS Fargate behind an ALB, RDS PostgreSQL, GitHub Actions with OIDC, in
`ap-southeast-2`). The findings and the fixes are real.

> **Status: in progress.** The audit role is applied (MFA assume-role tested)
> and both scan scripts have run as smoke tests. The baseline scan, the fixes, the after scan and the report are not done yet, so
> the results section below is empty on purpose. Nothing in this README is a
> measured result unless a saved scan backs it.

## What the audit covers

| Scan | Tool | Target | Needs AWS? |
|---|---|---|---|
| Live account | [Prowler](https://github.com/prowler-cloud/prowler) `aws`, CIS benchmark plus all checks, region `ap-southeast-2` | Account settings (IAM, root, CloudTrail, S3 account block, EBS defaults) and the deployed staging stack | Yes, read-only role |
| Terraform code | [Checkov](https://github.com/bridgecrewio/checkov) on the directory | Project 1 root module and modules | No |
| Pipeline code | Checkov `github_actions` framework | Project 1 `.github/workflows/` | No |

Every finding is placed in one of four buckets: **fix now**, **fix later**,
**accepted risk** (with the reason) or **could not evaluate** (with the reason).

This is a configuration audit. It does not include penetration testing, and it
does not turn on GuardDuty, Security Hub, Config or Inspector (the report may
recommend them).

## How to give me read-only access

You create one IAM role, `security-audit`, from a template. No access keys are
shared. The role has only read permissions:

- AWS managed `SecurityAudit` and `ViewOnlyAccess`
- a small extra read-only policy that Prowler needs (copied from Prowler 5.49.0,
  minus the write action `securityhub:BatchImportFindings`)

The role trusts one IAM principal (mine), requires MFA, and can require an
`sts:ExternalId` that you and I agree on. Sessions last one hour by default.

Pick one template. Both create the same role.

**Terraform** (`audit-role/`)

```bash
cd audit-role
cp terraform.tfvars.example terraform.tfvars   # set trusted_principal_arn, optionally external_id
terraform init
terraform plan
terraform apply
```

**CloudFormation** (`audit-role/cloudformation.yaml`)

Create a stack from the template and fill in the parameters
`TrustedPrincipalArn`, and optionally `ExternalId`, `RoleName` and
`MaxSessionDuration`.

**A note on the extra policy.** Three actions in it can read content, not only
metadata: `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` and
`lambda:GetLayerVersion` (they can download image layers and Lambda layers).
If that is not acceptable for your account, remove them before creating the
role. Some Prowler checks will then show as "could not evaluate".

To remove all access afterwards, delete the role (`terraform destroy` or delete
the stack).

## How to run the scans

Needs Docker and Bash. Tool versions are pinned by image digest inside the
scripts.

**1. Assume the audit role with MFA.** Credentials stay in environment
variables only.

```bash
creds=$(aws sts assume-role \
  --role-arn <role arn> \
  --role-session-name audit-$(date +%F) \
  --serial-number <your MFA device arn> \
  --token-code <6-digit code> \
  --duration-seconds 3600 \
  --query Credentials --output json)

export AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId <<<"$creds")
export AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey <<<"$creds")
export AWS_SESSION_TOKEN=$(jq -r .SessionToken <<<"$creds")
unset creds
```

For a client account, add `--external-id <value>`.

**2. Run the scans.** Both take a label and the path to the project 1 checkout.
Use the same commands for `before` and `after`.

```bash
scans/prowler.sh --label before --project ../AwsEcsFoundationTerraform
scans/checkov.sh --label before --project ../AwsEcsFoundationTerraform
```

Output goes to `reports/<date>-<label>/`:

| Scan | Files |
|---|---|
| Prowler | CSV, JSON-OCSF, HTML |
| Checkov | CLI text, JSON, SARIF (Terraform and GitHub Actions) |

`reports/` is git-ignored because raw output contains the account ID and ARNs.
Only the redacted report is committed.

## Pinned versions

| Tool | Version |
|---|---|
| Prowler | 5.49.0 (image pinned by digest) |
| Checkov | 3.4.5 (image pinned by digest) |
| CIS framework | `cis_7.0_aws` (the CIS mapping of each finding; all checks run) |
| Terraform | `>= 1.10`, AWS provider `~> 6.0` |

## Results

Not available yet. This section will hold the before and after counts by
severity for each tool, with the check IDs that changed, once both scans have
run. See the status note at the top.

| | Before | After |
|---|---|---|
| Prowler by severity | _pending_ | _pending_ |
| Checkov Terraform | _pending_ | _pending_ |
| Checkov GitHub Actions | _pending_ | _pending_ |

Report: `report/audit-report.md` and a PDF copy (not written yet). A blank
`report/TEMPLATE.md` for new client jobs is planned.

## Known limits

- Region `ap-southeast-2` only (organization SCP).
- The SCP denies `ec2:DescribeInstances`, so Prowler checks that need it cannot
  run. They are reported as "could not evaluate", never as passed.
- Checkov open source does not give severities without a Prisma Cloud key.
  Checkov findings are rated from the matching Prowler check or by hand, and
  the report says which.
- Findings that belong to other resources in the same account are reported
  separately from the audited project's own findings.

## Cost and time

- The scans are free.
- The audited staging stack costs about $93 a month, so running it for one
  working day costs about $3. It is destroyed the same day the scans finish.
- ALB access logs add a few cents of S3 storage.
- Nothing is left running. Planned effort: two working days.

## Checks on this repo

GitHub Actions (`.github/workflows/checks.yml`) runs shellcheck, actionlint,
`terraform fmt -check`, `validate`, tflint, cfn-lint and Checkov on this repo.
It has no AWS access.

## Layout

```
audit-role/   read-only security-audit role (Terraform and CloudFormation)
scans/        prowler.sh and checkov.sh
reports/      raw scan output (git-ignored)
report/       audit report, PDF and template (to be written)
```

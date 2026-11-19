# AWS Security Audit

A sample AWS security audit: scan a live account and its infrastructure code,
rank every finding by severity, fix the important ones and prove the fixes with
a second scan.

The target is my own working stack,
[AwsEcsFoundationTerraform](https://github.com/joheee/AwsEcsFoundationTerraform)
(VPC, ECS Fargate behind an ALB, RDS PostgreSQL, GitHub Actions with OIDC, in
`ap-southeast-2`). The findings and the fixes are real.

> **Status: scans, report and PDF done (updated 2026-11-20).** The baseline
> (2026-11-18) and after (2026-11-20) scans are saved, and the fixes were
> applied to a staging stack that has since been destroyed. The report is in
> `report/audit-report.md` with a PDF copy; the triage buckets were confirmed
> on 2026-11-20. Every number below comes from a saved scan.

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
| pandoc (PDF only) | 3.14 in `pandoc/latex`, image pinned by digest in `report/make-pdf.sh` |

## Results

Baseline 2026-11-18 (project 1 at `6a87780`, docs only on top of `7dc21e5`)
and after 2026-11-20 (project 1 at `9f8c0be`). Same commands, tool versions
and scope in both: Prowler 5.49.0 and Checkov 3.4.5.

| | Before | After |
|---|---|---|
| Prowler FAIL rows | 126: 1 critical, 23 high, 72 medium, 30 low | 134: 1 critical, 21 high, 80 medium, 32 low |
| Checkov Terraform (directory) | 195 passed, 18 failed | 235 passed, 23 failed |
| Checkov Terraform (plan JSON) | 152 passed, 20 failed | 180 passed, 25 failed |
| Checkov GitHub Actions | 118 passed, 2 failed | 118 passed, 2 failed |

**Failures went up, not down, and that is the honest result.** The fixes closed
findings (Prowler 6, Checkov 4 per Terraform scan) but also added resources
that fail lower-severity checks (Prowler 14, Checkov 9 per Terraform scan):
an access-log bucket for the load balancer and new log groups. Those are listed
in the report, not hidden. On the audited stack itself, high-severity Prowler
rows went from 9 to 7.

Prowler's rows include account-level findings and other projects' resources,
which were not changed (86 rows, identical before and after). The audited
stack's own rows went from 31 to 37, plus 2 on a log group AWS creates, and 9
on its hand-made state bucket.

Fixes applied to staging, one commit per change in project 1: RDS log exports
(CKV_AWS_129), RDS query logging (CKV2_AWS_30), RDS enhanced monitoring
(CKV_AWS_118), ALB access logs to a locked S3 bucket (CKV_AWS_91),
confused-deputy conditions on three service roles, a narrower CI apply role,
and GitHub Actions pinned to commit SHAs.

**Not fixed:** the staging CI apply role was narrowed but Prowler still flags it
for privilege escalation; the production apply role was left as it is by
decision; an attempt to disable RDS Extended Support did not change the live
value and was reverted.

Report: [`report/audit-report.md`](report/audit-report.md) and a PDF copy,
[`report/audit-report.pdf`](report/audit-report.pdf). To rebuild the PDF after
editing the report, run `report/make-pdf.sh` (needs Docker; pandoc runs in a
pinned image). A blank [`report/TEMPLATE.md`](report/TEMPLATE.md) is there for
new client jobs.

## Known limits

- Region `ap-southeast-2` only (organization SCP).
- The org SCP was believed to deny `ec2:DescribeInstances`. The call succeeded
  as the admin user on 2026-11-18 (the account has no EC2 instances), but it was
  not tested as the audit role. Checks that error are reported as "could not
  evaluate", never as passed.
- Checkov open source does not give severities without a Prisma Cloud key.
  Checkov findings are rated from the matching Prowler check or by hand, and
  the report says which.
- Findings that belong to other resources in the same account are reported
  separately from the audited project's own findings.

## Cost and time

- The scans are free.
- The audited staging stack costs about $93 a month, about $3 a day. It ran
  from 2026-11-17 to 2026-11-19 and was destroyed after the after scans.
- ALB access logs add a few cents of S3 storage.
- Nothing is left running. One manual production database snapshot was kept
  by decision. Planned effort was two working days; the scans and fixes ran from 2026-11-17 to 2026-11-20.

## Checks on this repo

GitHub Actions (`.github/workflows/checks.yml`) runs shellcheck, actionlint,
`terraform fmt -check`, `validate`, tflint, cfn-lint and Checkov on this repo.
It has no AWS access.

## Layout

```
audit-role/   read-only security-audit role (Terraform and CloudFormation)
scans/        prowler.sh and checkov.sh
reports/      raw scan output (git-ignored)
report/       audit-report.md and .pdf, TEMPLATE.md, checkov-triage-draft.md, make-pdf.sh
```

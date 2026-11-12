# Project goals: AWS security audit with fixes, shown on my own foundation

This repo (joheee/AwsSecurityAudit) is portfolio project #6 for my Upwork
DevOps profile. The point is the **sample report**: a client should look at it
and think "this person will find what is wrong in my AWS account, tell me how
bad each problem is, fix the important ones and prove they are fixed".

Audit jobs on Upwork ask the same thing again and again: "attach a sample
report". This project is that sample. The target is my own project 1
([joheee/AwsEcsFoundationTerraform](https://github.com/joheee/AwsEcsFoundationTerraform)):
a VPC, ECS on Fargate behind an ALB, RDS PostgreSQL and GitHub Actions with
OIDC in `ap-southeast-2`. It is a real, working stack, so the findings are real
and so are the fixes.

## The pitch (what a client buys)

> "AWS security audit with a written report and fixes, 2 days." I scan the
> live account with Prowler (CIS AWS benchmark) and the Terraform and GitHub
> Actions code with Checkov, from a read-only role you create with one
> template (no access keys shared). You get a report that ranks every finding
> by severity, says what it means for your business in plain words, and gives
> the exact fix. I fix the critical and high ones in your Terraform, scan
> again and show you the before and after numbers.

It matches jobs like "AWS gap analysis", "AWS environment review", "HIPAA
security review", "IAM clean-up" and "security audit with sample report"
($100 to $2,000 in the demand research).

## What gets scanned

| Scan | Tool | Target | Needs AWS? |
|---|---|---|---|
| Live account | Prowler `aws`, CIS benchmark plus all checks, region `ap-southeast-2` | Account-level settings (IAM, root, CloudTrail, S3 account block, EBS defaults) and the deployed project 1 staging stack | Yes, read-only role |
| Terraform code | Checkov on the directory and on the plan JSON | Project 1 root module and modules | No (plan JSON needs a `terraform plan`) |
| Pipeline code | Checkov `github_actions` framework | Project 1 `.github/workflows/` | No |
| Second opinion (optional) | Prowler `iac` (Trivy) | Project 1 code | No |

The live scan needs project 1 staging deployed for a few hours (before scan,
fixes applied, after scan), then destroyed. Prod is not deployed for this; its
differences (multi-AZ, deletion protection, two NAT gateways) are covered by
the code scans.

## Objectives

1. **Read-only audit role (`audit-role/`).** A small Terraform stack (and a
   CloudFormation copy for clients who don't use Terraform) that creates a
   `security-audit` role with the AWS managed `SecurityAudit` and
   `ViewOnlyAccess` policies plus Prowler's extra read-only policy. Assumed
   from my own admin user with MFA required; no access keys. External ID
   supported for client accounts. This is the "send this to the client"
   onboarding piece.
2. **Repeatable scan scripts (`scans/`).** `prowler.sh` and `checkov.sh` with
   pinned tool versions (Prowler and Checkov in Docker images with digests),
   writing raw output to `reports/<date>-<label>/` (CSV, JSON-OCSF, HTML for
   Prowler; JSON, SARIF and CLI text for Checkov). One command each, so the
   before and after runs are identical. `--label before` / `--label after`.
3. **Baseline scan ("before").** Run both scans against project 1 at commit
   7dc21e5 with staging deployed. Save the raw output and the exact commands.
   Record the counts by severity and by service.
4. **Triage and the written report (`report/`).** Every failed finding goes in
   one of four buckets: fix now, fix later (planned), accepted risk (with the
   reason), or not applicable / could not evaluate. Checks that the org SCP
   blocks (`ec2:DescribeInstances` and anything else that errors) are listed
   as "could not evaluate" with the reason, not hidden. Findings that belong
   to other projects in the same account (project 3's S3 bucket and IAM user,
   account defaults) are reported separately from project 1's own findings.
   Checkov open source does not give severities without a Prisma Cloud key, so
   Checkov findings get a severity from the matching Prowler check or my own
   rating, and the report says which.
5. **Fix a handful, in project 1.** Fix at least the critical and high
   findings that make sense for project 1, plus a few cheap medium ones, as
   normal commits in the project 1 repo through its own workflow. Likely
   candidates, to confirm after the baseline: RDS log exports and enhanced
   monitoring, ALB access logs to a locked S3 bucket, GitHub Actions pinned to
   commit SHAs, tighter IAM statements, account settings such as an IAM
   password policy, S3 account-level public access block and EBS default
   encryption. Every fix is one commit that names the check ID it closes.
6. **After scan and before/after table.** Re-run the exact same scans, save
   the output, and put a table in the report: findings by severity before
   and after, per tool, with the check IDs that changed. Also note any
   finding that a fix introduced.
7. **Client-ready report.** `report/audit-report.md` and a PDF copy:
   one-page summary for the business owner (scope, date, overall rating, top
   five risks, what was fixed), then findings by severity with impact, evidence
   (redacted), fix and status, then method, tool versions and limits. Account
   ID, ARNs with account numbers and IPs are redacted in the published copy.
   A blank `report/TEMPLATE.md` to reuse on client jobs.
8. **Client-style README.** What the audit covers, how to give me read-only
   access (the role template), how to run the scans yourself, the
   before/after table, a link to the report and PDF, cost and time.

## Stretch

- Run Checkov as a hard gate in project 1's workflow for critical/high (soft
  fail for the rest), so new findings block a run.
- A scheduled GitHub Actions job (OIDC, the audit role) that runs Prowler
  weekly and posts the summary. Only if it costs nothing.
- Map the findings to a second framework that clients ask for (for example
  AWS Foundational Security Best Practices or ISO 27001) with Prowler's
  `--compliance` flag.

## Out of scope

- Turning on GuardDuty, Security Hub, AWS Config or Inspector. They cost
  money after the trial and belong to the planned project 9 (security
  baseline). The report can recommend them.
- Penetration testing or attacking the ALB. This is a configuration audit.
- Scanning other projects' code (2, 3, 4). Their account-level resources show
  up in the Prowler scan and are reported, but not fixed here.
- Fixing every finding. The point is a ranked list, the important fixes and an
  honest "accepted risk" section, as a real client audit would have.
- Multi-account or organization-wide audits.

## Constraints

- Region `ap-southeast-2` only (org SCP). The SCP also denies
  `ec2:DescribeInstances`, so some Prowler EC2 checks error; report them as
  "could not evaluate".
- The org may manage CloudTrail, GuardDuty or Security Hub centrally. Check
  on day 1 and report what the account can't see or change.
- Cost: the scans are free. Project 1 staging costs about $93 a month, so
  running it for one working day costs about $3; destroy it the same day.
  ALB access logs add a few cents of S3. Nothing standing.
- No access keys. The scan runs as the assumed audit role with MFA; the
  session credentials stay in the shell and never in a file in the repo.
- Raw scan output contains the account ID and resource ARNs; `reports/` is
  git-ignored and only the redacted report is committed.

## Plan (2 days)

| Day | Work |
|---|---|
| 1 | Audit role applied. Scan scripts with pinned versions. Staging deployed. Baseline Prowler and Checkov scans saved. Triage every finding into the four buckets. |
| 2 | Fixes in project 1 (one commit per check), applied to staging. After scans, before/after table. Report and PDF, README, staging destroyed. Upwork portfolio entry. |

## Tools and software

Prowler (AWS and IaC providers) · Checkov (Terraform, plan JSON, GitHub
Actions) · CIS AWS Foundations Benchmark · AWS IAM (read-only audit role,
MFA, external ID) · Terraform (>= 1.10) with the AWS provider 6.x ·
CloudFormation (role template) · Docker · Bash · GitHub Actions · pandoc
(PDF)

## Definition of done

- [ ] `audit-role/` creates a read-only `security-audit` role (SecurityAudit, ViewOnlyAccess, Prowler additions) that needs MFA; CloudFormation copy included.
- [ ] `scans/prowler.sh` and `scans/checkov.sh` run with pinned image digests and write to `reports/<date>-<label>/`.
- [ ] Baseline scans saved for project 1 at a named commit, with counts by severity.
- [ ] Every failed finding is triaged: fix now, fix later, accepted risk (with reason) or could not evaluate (with reason).
- [ ] Critical and high project 1 findings fixed (or explained), one commit per check ID in the project 1 repo.
- [ ] After scans saved; the report has a before/after table by severity for each tool.
- [ ] `report/audit-report.md` and PDF: summary page, findings by severity, fixes, accepted risks, method and limits; account details redacted.
- [ ] `report/TEMPLATE.md` exists for client jobs.
- [ ] No access keys, account IDs or raw scan output committed; staging destroyed after the scans.
- [ ] README has scope, how to grant access, how to run the scans, the before/after table and links to the report.

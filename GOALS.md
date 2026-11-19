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

- Region `ap-southeast-2` only (org SCP). The SCP was believed to deny
  `ec2:DescribeInstances`; on 2026-11-18 it succeeded as the admin user (not
  tested as the audit role). Report what is observed, and list checks that
  error as "could not evaluate".
- The org may manage CloudTrail, GuardDuty or Security Hub centrally. Check
  on day 1 and report what the account can't see or change.
- Cost: the scans are free. Project 1 staging costs about $93 a month, so
  running it for one working day costs about $3; destroy it the same day.
  ALB access logs add a few cents of S3. Nothing standing.
- No access keys. The scan runs as the assumed audit role with MFA; the
  session credentials stay in the shell and never in a file in the repo.
- Raw scan output contains the account ID and resource ARNs; `reports/` is
  git-ignored and only the redacted report is committed.

## Progress (updated 2026-11-19)

Done:

- `audit-role/` (Terraform) is applied. Assume-role with MFA works and the
  read-only boundary is confirmed (`iam:CreateUser` is denied). The
  CloudFormation copy is only linted, not deployed, and the external ID path is
  untested.
- Both scan scripts work. CIS `cis_7.0_aws` is a mapping only (never
  `--compliance`). `checks.yml` is green.
- Staging of project 1 is deployed (it was applied after 2026-11-17 15:39) and
  **is still running and costing money**. A full staging plan says "No changes".
- Baseline scans saved in `reports/2026-11-18-baseline/` (git-ignored), all at
  project 1 `6a87780` (docs-only on top of `7dc21e5`, 0 uncommitted files):
  - Checkov 3.4.5: Terraform 195 passed / 18 failed; GitHub Actions 118 / 2;
    plan JSON 152 / 20 (plan is a no-op against deployed staging; plan JSON
    works, so keep it for the after scan).
  - Prowler 5.49.0, 668 checks executed: 126 FAIL (1 critical, 23 high,
    72 medium, 30 low), 270 PASS, 6 MANUAL. 25 FAIL rows are project 1's own
    resources, 9 are its hand-made state bucket, the rest are account level or
    other projects. Raw output and the plan JSON are in `reports/`; the plan
    files `baseline.tfplan`, `baseline-plan.json` and `apply-scope.tfplan` hold
    the account ID, so they stay there.
- `report/checkov-triage-draft.md` (committed in `2f486a2`) has the Checkov
  triage and the Prowler triage with proposed buckets. Prowler severities are
  used where a Checkov check has a matching Prowler check.
- Fixes in project 1, one commit per check, pushed and applied to staging
  through the Terraform workflow on 2026-11-18:
  - `3c792fb`: the staging apply role's IAM writes are limited to this
    environment's service roles (Prowler
    `iam_inline_policy_allows_privilege_escalation`, no Checkov check). Run #11.
  - `e51ea0e`: RDS logs exported to CloudWatch (CKV_AWS_129). Run #12.
  - `e101810`: RDS query logging through a parameter group (CKV2_AWS_30).
    Run #13 failed, run #14 passed on the same commit.
  - `5b0232f` and `056cb9c`: RDS enhanced monitoring (CKV_AWS_118); run #15
    failed on the PassRole condition, `056cb9c` fixed it in run #16.
  - `5403238` ("feat: fix error ecs"): ALB access logs to a locked S3 bucket
    (CKV_AWS_91), applied on 2026-11-19 (run `44573826722`) after the apply
    and plan role policies were applied locally. Bucket settings checked with
    the CLI; the ALB `access_logs` attribute could not be read (SCP deny on
    `DescribeLoadBalancerAttributes`), so the evidence is the ELB test object.
  - `5c52501`: confused-deputy conditions on the staging ECS execution, ECS
    task and VPC flow-logs roles (Prowler
    `iam_role_cross_service_confused_deputy_prevention`, no Checkov check).
    Run `44575339368`. Trust policies verified. On 2026-11-19 a forced ECS
    deployment started a new task and passed health checks, and 1,916 flow
    log records ended after the change (delivery `SUCCESS`). The task role
    itself was not exercised separately (the sample app calls no AWS APIs).
  - `a9d7511`: all 11 `uses:` lines in project 1's two workflows pinned to
    commit SHAs, exact version in a comment (hand-found, no check ID; neither
    Checkov nor Prowler flags it). Run `44579607339` passed: plan "No changes",
    apply 0 changed.
  - `315c976`, `af507da`, reverted by `9f8c0be`: tried to disable RDS Extended
    Support (`rds_instance_extended_support`). The workflow passed but the live
    value did not change (even with `apply_immediately`), so it is **not fixed**
    and not counted. Staging plan is "No changes" again (run `44584815581`).
  The prod apply role still has the old broad policy. The after scan decides
  whether Prowler still flags the apply role.

Found along the way:

- The GitHub OIDC provider was missing from the account on 2026-11-17 and was
  recreated by hand, so it has no Terraform owner (exists as of 2026-11-18).
  Mention it in the report as a cross-project dependency.
- The `ecs-foundation-prod-final` RDS snapshot still exists. Do not delete it
  unasked.
- `ec2:DescribeInstances`: the admin user got 0 reservations on 2026-11-18, so
  it was not denied there, and the account has no EC2 instances. Prowler has no
  `ec2_instance_*` rows. Not tested as the `security-audit` role. Word the
  report as observed, not as "blocked by the SCP".
- 2 Prowler rows are `us-east-1`: Trusted Advisor, which is served from there.
- Apply role finding root cause: `name_prefix` is `ecs-foundation-*`, so the
  apply role could rewrite itself and the other environment's apply role.
- A prod container-insights log group (`/aws/ecs/containerinsights/ecs-foundation-prod/...`)
  shows up in the findings although prod is not deployed. Probably a leftover.
  Confirm.
- Project 1's README triages CKV_AWS_336 as accepted; the plan is to fix it
  later instead (`readonlyRootFilesystem` plus tmpfs for nginx). The report
  must say it differs.

"To confirm" rows resolved on 2026-11-19 (evidence and **proposed** buckets in
`report/checkov-triage-draft.md`, committed `3a3b0b7`): no AWS Backup plan but
7-day automated backups; RDS enrolled in Extended Support (engine 17.9, end of
standard support not verified); the RDS-managed secret has no resource policy
(as the admin user, not tested as the audit role); the 2 failing NACLs are both
VPC default ACLs, one in project 1's VPC and one in the account's default VPC;
the prod container-insights log group is a leftover (no prod cluster exists).

After scans (2026-11-20, `reports/2026-11-20-after/`, project 1 `9f8c0be`,
same commands and pins as the baseline): Checkov Terraform 195/18 to 235/23,
GitHub Actions 118/2 to 118/2, plan 152/20 to 180/25; Prowler FAIL 126 to 134
(critical 1 to 1, high 23 to 21, medium 72 to 80, low 30 to 32), PASS 270 to
301, MANUAL 6 to 6. Closed: Checkov 4 (CKV_AWS_91, 118, 129, CKV2_AWS_30) and
Prowler 6 (3 confused-deputy, ALB logging, RDS log export, enhanced
monitoring). Introduced by fixes: Checkov 9 in each of Terraform and plan;
Prowler 14 (ALB log bucket 11 rows including `s3_bucket_cross_account_access`
high, 3 log-group rows including AWS-created `RDSOSMetrics`). Not closed: the
staging apply role still fails `iam_inline_policy_allows_privilege_escalation`
(6 actions still flagged, `iam:CreatePolicyVersion` removed). The Checkov plan
scan also has a new CKV2_AWS_69 (cause not confirmed). Staging destroyed
(Destroy run `44589344952`, 61 resources); `ecs-foundation-prod-final` kept.

Open: the day-1 check of whether the org manages CloudTrail, GuardDuty or
Security Hub centrally; where staging was deployed from (local or workflow);
what to do with the prod snapshot; whether the account-level S3 public access
block and IAM password policy are in scope as fixes or report-only (decide
before the after scan; both change the whole account, show and ask first);
the project 1 default NACL (Accepted or Fix later); and the user has
not yet confirmed any of the proposed buckets above.

Next, in order:

1. Prod apply role: decided 2026-11-19 to leave it as is and report it as a
   known difference (prod is not deployed; its apply role still has the old
   broad policy, so the after scan will still flag
   `iam_inline_policy_allows_privilege_escalation` for it). The staging role is
   fixed in `3c792fb`.
2. Finish the triage: diff the plan-JSON failures against the directory
   failures line by line (not done), get the user's decision on the proposed
   buckets, then re-measure the project 1 versus other split from both CSVs
   (the project 1 default NACL adds rows).
3. Before/after tables, report, PDF, `TEMPLATE.md`, README results. The after
   scans are saved (see Progress). No AWS access is needed for this.
4. Delete the saved plan files in `reports/` (they hold the account ID).
5. Recheck the 4 automated RDS snapshots of the staging DB that were still
   listed after the destroy.

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

- [x] `audit-role/` creates a read-only `security-audit` role (SecurityAudit, ViewOnlyAccess, Prowler additions) that needs MFA; CloudFormation copy included. _(Terraform applied; MFA assume-role works and `iam:CreateUser` is denied. The CloudFormation copy is linted, not deployed)_
- [x] `scans/prowler.sh` and `scans/checkov.sh` run with pinned image digests and write to `reports/<date>-<label>/`. _(Prowler smoke scan `smoke2`: 668 of 675 checks in 4:32; Checkov matches project 1's README, 18 failed / 195 passed)_
- [x] Baseline scans saved for project 1 at a named commit, with counts by severity. _(`reports/2026-11-18-baseline/`, project 1 `6a87780`. Prowler has severities; Checkov has pass/fail counts only)_
- [ ] Every failed finding is triaged: fix now, fix later, accepted risk (with reason) or could not evaluate (with reason).
- [ ] Critical and high project 1 findings fixed (or explained), one commit per check ID in the project 1 repo.
- [ ] After scans saved; the report has a before/after table by severity for each tool.
- [ ] `report/audit-report.md` and PDF: summary page, findings by severity, fixes, accepted risks, method and limits; account details redacted.
- [ ] `report/TEMPLATE.md` exists for client jobs.
- [ ] No access keys, account IDs or raw scan output committed; staging destroyed after the scans.
- [ ] README has scope, how to grant access, how to run the scans, the before/after table and links to the report.

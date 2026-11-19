# CLAUDE.md

Read `GOALS.md` first. It defines what this repo creates, what is out of scope
and the definition of done. When a choice is unclear, pick the option that makes
the "a sample audit report a client would pay for, with fixes proven by a
second scan" story clearer.

## Context

- This repo (joheee/AwsSecurityAudit) is portfolio project #6: a security
  audit of project 1 (joheee/AwsEcsFoundationTerraform) with Prowler and
  Checkov, a written report ranked by severity, a few fixes and a
  before/after scan.
- The fixes themselves are made in the project 1 repo (its CLAUDE.md rules
  apply there). This repo holds the audit role, the scan scripts and the
  report.
- Region `ap-southeast-2` only (org SCP). The SCP was believed to deny
  `ec2:DescribeInstances`, but the call succeeded as the admin user on
  2026-11-18 (0 instances; not tested as the audit role). Report what is
  observed. Checks that error are "could not evaluate", never passed; don't try
  to work around the SCP.
- The GitHub OIDC provider is looked up with a data source, never created here.
  It was missing on 2026-11-17 and was recreated by hand; check it exists
  before planning project 1 (`aws iam list-open-id-connect-providers`).

## Layout

- `audit-role/`: Terraform for the read-only `security-audit` role
  (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`) and
  `cloudformation.yaml` with the same role for clients. Local state is fine;
  it is one role. `terraform.tfvars` (git-ignored) holds the trusted principal
  ARN; `terraform.tfvars.example` is the template. The Prowler additions policy
  is copied from upstream (5.49.0) minus `securityhub:BatchImportFindings`; keep
  the Terraform and CloudFormation action lists identical and re-diff against
  upstream when the Prowler pin changes.
- `scans/`: `prowler.sh` (AWS scan, region `ap-southeast-2`, CIS plus all
  checks, CSV, JSON-OCSF and HTML) and `checkov.sh` (directory, plan JSON and
  `github_actions`; JSON, SARIF and CLI text). Both take `--label` and the
  path to the project 1 checkout, and write to `reports/<date>-<label>/`.
- `reports/`: raw scan output. Git-ignored, because it holds the account ID
  and ARNs.
- `report/`: `audit-report.md`, the PDF, `TEMPLATE.md` and redacted excerpts.
- `.github/workflows/checks.yml`: shellcheck, actionlint, `terraform fmt
  -check`, `validate`, tflint, cfn-lint and Checkov on this repo. No AWS
  access. Actions pinned by SHA, tools by image digest or version.

## Working rules

- Never commit access keys, session tokens, `.env`, `*.tfstate`,
  `.terraform/`, raw `reports/` output or an unredacted account ID. Commit
  `*.example` files.
- The scans run as the assumed `security-audit` role with MFA. Never create an
  access key for the audit. Session credentials stay in environment variables.
- The audit role is read-only: AWS managed `SecurityAudit` and
  `ViewOnlyAccess` plus Prowler's additions policy. Don't add write actions.
  Explain any `"*"` resource in a comment (the managed policies use it).
- Trust policy: my own IAM principal with `aws:MultiFactorAuthPresent`, and
  `sts:ExternalId` as a variable for client accounts. OIDC trust (stretch)
  pins this exact repo and the `main` branch; never `repo:joheee/*`.
- Pin tool versions: Prowler and Checkov images by digest, Terraform and
  provider in `versions.tf`, GitHub Actions by commit SHA. Commit
  `.terraform.lock.hcl`.
- Before and after scans must use the same commands, versions and scope, or the
  comparison means nothing. Record the commands and versions in the report.
- Don't claim counts or results that haven't been measured. Every number in
  the report comes from a saved scan.
- Redact the account ID, ARNs with account numbers, IPs and email addresses in
  anything committed.
- Account-level changes (password policy, S3 account public access block, EBS
  default encryption) change the whole account. Show the exact change and ask
  first.
- Never deploy, apply or destroy project 1 or the audit role without being
  asked; show the plan first. Destroy project 1 staging the same day the scans
  finish, and check the `ecs-foundation-prod-final` snapshot is gone.
- Cost: flag anything that adds standing cost. Don't enable GuardDuty,
  Security Hub, Config or Inspector here.
- Run `terraform fmt -recursive`, `terraform validate`, `tflint`, `shellcheck`
  and `actionlint` before every commit.
- Commits: author `joheee <johevinblesstowi07@gmail.com>`, no Co-Authored-By
  trailer. Ask before committing or pushing. Push to `main`.
- Tick the boxes in the GOALS.md "Definition of done" as items are finished.

## Pinned versions (keep in sync with the scripts and the workflow)

- Prowler 5.49.0 (`prowlercloud/prowler`, digest in `scans/prowler.sh`), CIS
  framework `cis_7.0_aws` (decided 2026-11-17; all 675 checks run, CIS is the mapping, not
  a filter: never add `--compliance`).
- Checkov 3.4.5 (`bridgecrew/checkov`, digest in `scans/checkov.sh` and
  `checks.yml`).
- Terraform 1.15.9 in CI, `>= 1.10` in `versions.tf`, AWS provider `~> 6.0`.
- tflint 0.64.0, cfn-lint 1.60.1, ShellCheck 0.11.0, actionlint 1.7.12.
- Changing any Prowler or Checkov pin means re-running both before and after.

## Notes

- Checkov open source shows no severities without a Prisma Cloud API key. Rate
  Checkov findings from the matching Prowler check or by hand, and say which.
- Checkov on project 1 at `7dc21e5` (measured with 3.4.5): Terraform 195
  passed, 18 failed; GitHub Actions 118 passed, 2 failed (the 2 are not in
  project 1's README). Plan JSON: decided 2026-11-17 to try it
  during staging setup; if it is awkward, drop it for both before and after and
  say so in the report limits.
- Checkov on this repo is a hard gate. The only skip is `CKV_AWS_356` on the
  Prowler additions policy (read-only `"*"`), inline with a reason. Add other
  skips the same way, never in a global config.
- `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` and `lambda:GetLayerVersion`
  in the additions policy can download content, not only metadata. Mention this
  in the client onboarding notes.
- Commit trailer: this file wins over any tool default. No Co-Authored-By.
- Project 1's README already triages 18 Checkov findings (195 passed). Start
  from that list; the audit should add the live account view, severities and
  proof of the fixes, not repeat it.
- Prowler reports permission errors as `MANUAL` or errors in the log rather
  than FAIL. Collect those for the "could not evaluate" section.
- Use `--resource-tags project=<project 1 value>` only for a focused re-check.
  The main scans cover the whole region so account-level findings show up.
- Never add `--compliance` to `prowler.sh`: it limits the run to that
  framework (82 of 675 checks for CIS 7.0). CIS is read from the `COMPLIANCE`
  column and `compliance/prowler_cis_7.0_aws.csv`.
- Session flow: `aws login` as the admin user, assume `security-audit` with MFA
  (serial and code), export the three variables, run the scan, `unset` them.
  An assume-role session lasts one hour; a full scan took 4:32 on an empty
  account.
- Project 1 deploys staging from its own repo: init with
  `-backend-config=envs/staging.backend.hcl`, plan with
  `-var-file=envs/staging.tfvars`. Its CI roles survive a destroy by design, so
  the apply roles appear in every Prowler scan. Save plans outside both repos
  or in git-ignored `reports/`; they contain the account ID.
- Account-level findings (admin policy on a group, CloudTrail, S3 account block,
  users without MFA) are reported separately from project 1's own findings.
- The `ecs-foundation-prod-final` snapshot existed on 2026-11-17. Do not delete
  it without asking.
- Baseline (2026-11-18): scans are in `reports/2026-11-18-baseline/`
  (project 1 `6a87780`; Checkov 195/18, 118/2, plan 152/20; Prowler 126 FAIL:
  1 critical, 23 high, 72 medium, 30 low). Plan JSON works, keep it for the
  after scan. Staging of project 1 is deployed and still costing money: destroy
  it the day the after scans finish. `GOALS.md` "Next" lists the order of work.
- Each `!` command in a Claude Code session runs in its own shell, so exported
  AWS variables do not reach later commands. Run the Prowler scan in the same
  shell, with the variables set inline on the `scans/prowler.sh` line, or run
  it from your own terminal. The MFA code lasts about 30 seconds and works
  once. Never ask for the credentials in chat.
- Project 1 commit `3c792fb` (pushed, tested from the workflow on 2026-11-18)
  limits the apply role's IAM writes to the environment's service roles (now
  four, with `rds-monitoring`). Project 1 apply roles are changed locally with
  `-target=aws_iam_role_policy.apply`, not from CI. The prod apply role still
  has the old policy and none of the 2026-11-18 additions. Any new project 1
  service role must be added to `service_role_arns` in project 1 `main.tf`, or
  its apply is denied.
- `report/checkov-triage-draft.md` holds the triage with proposed buckets.
  Only the items listed under its "Decisions" are decided.

## Project 1 fix workflow (learned 2026-11-18)

- Project 1's `terraform.yml` has no plan-only mode: it plans and then applies
  straight away. Triggering it is a real apply. The apply role cannot edit its
  own policy, so a fix that needs new permissions fails with 403 until the
  policy is applied locally (`-target=aws_iam_role_policy.apply`, plan saved in
  git-ignored `reports/`, show it first, the user runs the apply).
- The order that works: commit, plan the policy-only change, the user applies
  it, push, run the workflow on staging, then verify with the AWS CLI.
- Saved plans go stale when a pipeline run touches the state. Re-plan to a new
  file after any run, and tell the user to apply before anything else.
- Auto mode blocks a chained `terraform apply`. Never append an apply to a
  plan command; the user applies saved plans from their own terminal.
- RDS enhanced monitoring: `iam:PassRole` is evaluated with
  `iam:PassedToService = rds.amazonaws.com`, not `monitoring.rds.amazonaws.com`.
  Both are in the apply policy.
- ALB access logs support only SSE-S3 (not KMS) and, in `ap-southeast-2`, the
  regional ELB account principal (`aws_elb_service_account`).
- After a parameter group change the staging instance shows `pending-reboot`.
  Not rebooted; staging is destroyed after the scans.
- Fixes add findings too: each new log group fails CKV_AWS_158 and
  CKV_AWS_338, and the ALB log bucket fails CKV_AWS_18, 21, 144, 145 and
  CKV2_AWS_62 (accepted, log-only bucket). List them in the report as
  "introduced by a fix". Do not skip them to hide them.
- Counts from ad-hoc Checkov runs are not results. Only the saved before and
  after scans go in the report.

## State on 2026-11-19 (end of session)

- Project 1 fixes pushed and applied to staging, each verified through the
  workflow: `3c792fb` (apply role IAM, no Checkov check), `e51ea0e`
  (CKV_AWS_129), `e101810` (CKV2_AWS_30), `5b0232f` and `056cb9c`
  (CKV_AWS_118; the second fixes the PassRole condition). Workflow runs
  `44338832844`, `44343361441`, `44349042312` passed.
- CKV_AWS_91 (ALB access logs to a locked S3 bucket) is project 1 `5403238`
  ("feat: fix error ecs"), with the apply and plan roles' S3 permissions. The
  user applied the policy locally (`policy-alblogs.tfplan`), then workflow run
  `44573826722` passed (6 added, 1 changed). Verified with the AWS CLI: bucket
  public access block, SSE-S3, 30-day lifecycle, TLS-only policy and the
  `ELBAccessLogTestFile` object. The ALB `access_logs` attribute could not be
  read (see the SCP note below), so that part is indirect evidence.
- Confused-deputy conditions (`aws:SourceAccount` and `aws:SourceArn`) on the
  staging `ecs-execution`, `ecs-task` and `vpc-flow-logs` trust policies are
  project 1 `5c52501`. Workflow run `44575339368` passed (3 changed); trust
  policies verified with the AWS CLI. A forced ECS deployment then started a
  new task (health checks passed, no AccessDenied in the service log) and
  1,916 flow log records ended after the change (delivery `SUCCESS`). The task
  role was not exercised separately. No policy change was needed (the apply
  role can already update these roles' trust policies).
- Second observed SCP deny: `elasticloadbalancing:DescribeLoadBalancerAttributes`
  returned an explicit deny in an SCP for the admin user (2026-11-19). Not
  worked around. Report as observed; a check that needs it is "could not
  evaluate". Not tested as the audit role.
- GitHub Actions SHA pins are project 1 `a9d7511` (all 11 `uses:` lines, exact
  version in a comment). Run `44579607339` passed with "No changes".
- Prod apply role: decided 2026-11-19 to leave the old policy and report it as
  a known difference. Do not plan or apply it unless asked again. The after
  scan will still flag it for prod.
- Still to do, in order: triage "to confirm"
  rows; after scans; report; destroy staging.
- Staging is still running and costing about $3 a day (since 2026-11-17).
  The `ecs-foundation-prod-final` snapshot decision comes before the destroy.
- `reports/` holds saved plan files (`policy-*.tfplan`, `confused-deputy.tfplan`,
  `*.tfplan`). The 2026-11-19 ones are used up. They contain the account ID and
  are git-ignored. Delete them when the work is done.
- This file, `README.md` and `report/checkov-triage-draft.md` are committed
  (`2f486a2`). `GOALS.md` "Progress" lists the pushed fixes.

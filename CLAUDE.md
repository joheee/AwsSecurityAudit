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
- Region `ap-southeast-2` only (org SCP). The SCP also denies
  `ec2:DescribeInstances`; Prowler checks that need it will error. Report them
  as "could not evaluate", never as passed, and don't try to work around the
  SCP.
- The GitHub OIDC provider already exists in the account; reuse it with a data
  source if a workflow needs AWS, don't create another.

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
  framework `cis_7.0_aws` (provisional, confirm before the baseline).
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
  project 1's README). Plan JSON is not run yet.
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

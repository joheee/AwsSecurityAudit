# AWS Security Audit: sample report

**Status:** triage buckets confirmed by the owner on 2026-11-20; final read
done. Every number comes from a saved scan (see Method). Account IDs, ARNs with
account numbers, IP addresses and e-mail addresses are redacted.

| | |
|--------------|--------------------------------------------------------------------------------------|
| Audited system | A sample AWS foundation: VPC, ECS on Fargate behind an ALB, RDS PostgreSQL, GitHub Actions with OIDC. Code: [AwsEcsFoundationTerraform](https://github.com/joheee/AwsEcsFoundationTerraform) |
| Account | One AWS account (ID redacted), region `ap-southeast-2` |
| Baseline scan | 2026-11-18, code at `6a87780` |
| After scan | 2026-11-20, code at `9f8c0be` |
| Tools | Prowler 5.49.0 (CIS AWS benchmark mapping `cis_7.0_aws`, all checks), Checkov 3.4.5 |
| Access | A read-only `security-audit` role, assumed with MFA, no access keys |

## 1. Summary

**Overall rating: moderate for the audited stack, needs attention at account
level.** The audited stack has no public data store: the database is
private and reachable only from the application's security group. The main
open points are plain HTTP on the load balancer (accepted in this sample), a
CI deploy role that Prowler still flags for privilege escalation, and a
writable container filesystem. At account level the audit role found no
CloudTrail trail with logging enabled, and GuardDuty and Security Hub were not
enabled, in this region; the account
has broad administrator access and IAM users without hardware MFA. Those
findings are reported separately from the audited stack and were not changed.

**Top five risks** (ranked by what they would mean for a business):

1. **No visible logging or threat detection (account level).** Prowler found no
   CloudTrail trail with logging enabled, and GuardDuty and Security Hub not
   enabled, in the region. Whether the
   organization manages these centrally was not checked. Without them, a
   compromise may go unseen. Recommendation, not fixed here.
2. **Broad administrator access and weak MFA (account level).** The
   `AdministratorAccess` policy is attached, an admin policy is on a group, and
   two IAM users have long-lived credentials without hardware MFA. Not changed.
3. **Account-wide S3 public access block is off.** One account setting would
   stop any future bucket from being made public by mistake. Recommended; it
   changes the whole account, so it needs the owner's decision.
4. **Plain HTTP on the load balancer (audited stack).** Anything sensitive sent
   to the app would be readable on the network path. Accepted for this sample
   because HTTPS needs a domain and certificate. For a real client's public app
   this is a high-severity item.
5. **A CI deploy role that can escalate privileges (audited stack).** The role
   was narrowed (it can now change only the environment's own service roles),
   but Prowler still flags it. The production role was left unchanged by
   decision.

**What was fixed** (all in the audited stack, one commit per change, each
applied to staging through the project's pipeline and verified by the pipeline
run and, where the setting can be read, with the AWS CLI):

| Fix | Closes |
|----------------------------------------|------------------------------------------------------------|
| RDS logs exported to CloudWatch | Checkov CKV_AWS_129; Prowler `rds_instance_integration_cloudwatch_logs` |
| RDS query logging through a parameter group | Checkov CKV2_AWS_30 |
| RDS enhanced monitoring | Checkov CKV_AWS_118; Prowler `rds_instance_enhanced_monitoring_enabled` |
| ALB access logs to a locked S3 bucket | Checkov CKV_AWS_91; Prowler `elbv2_logging_enabled` |
| Confused-deputy conditions on three service roles | Prowler `iam_role_cross_service_confused_deputy_prevention` (3 rows) |
| CI apply role narrowed (staging) | Reduced the flagged actions; **finding still open** |
| GitHub Actions pinned to commit SHAs | Hand-found; neither tool flags it |

**Before and after, in one line each.** Prowler failures went from 126 to 134
and Checkov Terraform failures from 18 to 23, **because the fixes added new
resources that fail lower-severity checks** (listed in section 5). High-severity
findings on the audited stack went from 9 to 7. A client should read the lists,
not only the totals.

## 2. Before and after

### Prowler (live account, region `ap-southeast-2`)

| Failed rows | Critical | High | Medium | Low | Total |
|---|---|---|---|---|---|
| Before | 1 | 23 | 72 | 30 | 126 |
| After | 1 | 21 | 80 | 32 | 134 |

Passed rows 270 before and 301 after; manual-review rows 6 and 6. Counts are
result rows (one per resource), not distinct checks.

By owner (same rule in both scans, see Method):

| Group | Before | After |
|----------------------------------------|-----------------------------------|-------------------------|
| Audited stack | 31 (0 critical, 9 high, 19 medium, 3 low) | 37 (0, 7, 25, 5) |
| Log group created by AWS for enhanced monitoring (`RDSOSMetrics`) | 0 | 2 (medium) |
| The stack's hand-made Terraform state bucket | 9 (5 medium, 4 low) | 9 |
| Account level and other projects | 86 (1 critical, 14 high, 48 medium, 23 low) | 86 (identical) |

The account-level group is identical in both scans: nothing outside the
audited stack was changed.

Changes on the audited stack: 6 rows closed (3 high, 2 medium, 1 low), 12
introduced by fixes (8 on the ALB log bucket, 4 on the two new RDS log groups),
plus 2 on the AWS-created log group.

By service, failed rows before and after: S3 26 to 34, IAM 27 to 24,
CloudWatch 21 to 27, RDS 10 to 8, EC2 6 to 6, CloudTrail 5 to 5, ELBv2 4 to 3,
ECS 3 to 3; every other service is unchanged.

### Checkov (code)

Checkov open source gives no severities. Each finding is rated from the
matching Prowler check where one exists, otherwise by me. Counts are
failures, not distinct checks.

| Scan | Passed before | Failed before | Passed after | Failed after |
|---|---|---|---|---|
| Terraform, directory | 195 | 18 | 235 | 23 |
| Terraform, plan JSON | 152 | 20 | 180 | 25 |
| GitHub Actions | 118 | 2 | 118 | 2 |

Failures by rated severity:

| Scan | Rating | Before | After |
|---|---|---|---|
| Terraform, directory | High | 1 | 1 |
| | Medium | 13 | 17 |
| | Low | 3 | 4 |
| | Info | 1 | 1 |
| Terraform, plan | High | 1 | 1 |
| | Medium | 16 | 20 |
| | Low | 3 | 4 |
| GitHub Actions | Low | 2 | 2 |

Closed in both Terraform scans: CKV_AWS_91, CKV_AWS_118, CKV_AWS_129 and
CKV2_AWS_30. Introduced by fixes: 9 failures in each (section 5). The pinned
GitHub Actions do not change Checkov's count because it has no check for that.

The plan scan and the directory scan cover different things: the plan scan
sees real staging values (for example deletion protection off), and does not
evaluate data sources. They are not added together. CKV_AWS_260 appears twice
in the plan scan for one rule.

## 3. Findings on the audited stack

Status: **Fixed**, **Fix later**, **Accepted** (with the reason) or **Could
not evaluate**.

### High

| Finding | Evidence | Status | Notes |
|------------------------|----------------------------------|-------------|-----------------------------|
| Containers have a writable root filesystem (Prowler `ecs_task_definitions_containers_readonly_access`, Checkov CKV_AWS_336) | One container in the staging task definition | Fix later | `readonlyRootFilesystem` plus temporary mounts for the paths nginx writes. The project README had accepted this; the audit rates it high and plans a fix. |
| CI apply role can escalate privileges (Prowler `iam_inline_policy_allows_privilege_escalation`, 2 rows: staging and production roles) | Flagged actions for staging after the fix: `ecs:CreateService`, `ecs:RegisterTaskDefinition`, `iam:AttachRolePolicy`, `iam:PassRole`, `iam:PutRolePolicy`, `iam:UpdateAssumeRolePolicy` | **Accepted risk.** Staging: narrowed, still flagged. Production: unchanged by decision | The staging role can now change only the environment's four service roles (before it could rewrite roles by name pattern, including its own). The flagged actions remain because the pipeline needs them to deploy. |
| Database not covered by an AWS Backup plan (`rds_instance_protected_by_backup_plan`) | Automated backups with 7-day retention (staging; production sets 14) exist | Accepted | A backup plan adds standing cost. The check is about a plan, not about having backups. |
| RDS-managed secret has no restrictive resource policy (`secretsmanager_has_restrictive_resource_policy`) | No resource policy on the secret when read as the admin user | Accepted | Access is by IAM only. Not tested as the audit role, so partly could-not-evaluate. |
| Default network ACL allows all inbound (`ec2_networkacl_allow_ingress_any_port`) | The staging VPC's default ACL | Accepted | Security groups are the control; the ALB is the only public entry. It is a default ACL, not managed in Terraform; it could be locked down with `aws_default_network_acl`. |
| Bucket policy allows another AWS account (`s3_bucket_cross_account_access`, ALB log bucket) | The regional load-balancer service principal | Accepted | Required for ALB access logs. **Introduced by a fix.** |

### Medium

| Finding | Status | Notes |
|----------------------------------------|----------|--------------------------------------------------|
| ALB listener is HTTP only (Prowler `elbv2_ssl_listeners`; Checkov CKV_AWS_2, CKV_AWS_103, CKV2_AWS_20, CKV_AWS_378) | Accepted | HTTPS needs a domain and certificate. For a real public app this is high. Path: domain, certificate, 443 listener, redirect from 80. |
| No WAF on the ALB (`elbv2_waf_acl_attached`, CKV2_AWS_28) | Accepted | Standing cost. Recommended for a real client. |
| ALB and database deletion protection off, database single-AZ (`elbv2_deletion_protection`, `rds_instance_deletion_protection`, `rds_instance_multi_az`; CKV_AWS_150, CKV_AWS_293, CKV_AWS_157) | Accepted (staging) | Production sets all three. Staging is meant to destroy cleanly. |
| ECS Container Insights off in staging (`ecs_cluster_container_insights_enabled`, CKV_AWS_65) | Accepted | Cost; production turns it on. |
| Log groups not KMS-encrypted and without a long retention (10 rows: `cloudwatch_log_group_kms_encryption_enabled`, `..._retention_policy_specific_days_enabled`; CKV_AWS_158, CKV_AWS_338) | Accepted | Five groups: the service, flow-log and two RDS groups, plus a leftover from an earlier production run. AWS-managed encryption is in use; a customer key adds cost. Retention is 14 days in staging by design. Four of the rows are **introduced by fixes**. |
| RDS enrolled in Extended Support (`rds_instance_extended_support`) | Fix later | A fix was attempted: the setting was accepted by Terraform but the live value did not change, even with immediate apply, so it was reverted. Not fixed. Cause not confirmed; the only route not ruled out is setting it when the instance is created. |
| Default ACL allows SSH and RDP from anywhere (`ec2_networkacl_allow_ingress_tcp_port_22`, `..._3389`) | Accepted | Same ACL as above; no instance in the stack listens on those ports. |
| No Network Firewall; no VPC endpoint for EC2 (`networkfirewall_in_all_vpc`, `vpc_endpoint_for_ec2_enabled`) | Accepted | Standing cost; out of scope for a sample. |
| ALB log bucket: no KMS, MFA delete, versioning or access logging (4 rows) | Accepted | **Introduced by a fix.** Log-only bucket; ALB logs support SSE-S3 only (not KMS). Objects expire after 30 days. |
| `RDSOSMetrics` log group not encrypted or limited in retention (2 rows) | Accepted | Created automatically by AWS when enhanced monitoring is on. **Introduced by a fix.** |

### Low

| Finding | Status | Notes |
|----------------------------------------|----------|--------------------------------------------------|
| Container logging uses the default (blocking) mode (`ecs_task_definitions_logging_block_mode`) | Accepted | Non-blocking can drop logs. |
| Database uses the default port 5432 (`rds_instance_non_default_port`) | Accepted | The security group, not the port, is the control. |
| ALB security group allows port 80 from anywhere (CKV_AWS_260) | Accepted | It is the public entry point. |
| RDS Performance Insights not KMS-encrypted (CKV_AWS_354) | Accepted | AWS-managed key in use; cost. |
| `aws_availability_zones` data source does not pin zone identity (CKV_AWS_394) | Accepted | Style check on a data source; not a deployed-resource risk. |
| GitHub Actions workflow inputs (CKV_GHA_7, two workflows) | Accepted | The inputs select an environment; they do not change build output. |
| ALB log bucket: no replication, event notifications or object lock (3 rows) | Accepted | **Introduced by a fix.** |

### The stack's Terraform state bucket (hand-made, outside Terraform)

Nine rows (5 medium, 4 low): no KMS key, MFA delete, versioning, TLS-only
policy or access logging, and no replication, notifications, lifecycle or
object lock. Versioning and the TLS-only policy are **fix later**
(recovery from a bad state write, and TLS); the rest are accepted for a
one-person sample.

## 4. Account-level findings (not the audited stack)

These come from the same account but belong to the account itself or to other
projects. They were not changed. 86 rows, identical before and after.

| Theme | Rows | Highest | What it means |
|------------------|--------------|--------|------------------------------------------------------------|
| Logging, monitoring and detection | 31 (6 high, 21 medium, 4 low) | High | No CloudTrail trail with logging enabled, and GuardDuty, Security Hub, Inspector and the Config recorder not enabled, in the region; 15 log-metric alarms that depend on CloudTrail are missing. Whether the organization manages these centrally was not checked. Recommend; out of scope to enable here because of standing cost. |
| IAM: administrator access, MFA, credentials | 15 (1 critical, 6 high, 4 medium, 4 low) | Critical | The `AdministratorAccess` policy is attached; an admin policy sits on a group; two IAM users have long-lived credentials and lack hardware MFA; one cross-service role lacks a confused-deputy condition; unused Bedrock access. Report only. |
| Other projects' S3 buckets | 16 (9 medium, 7 low) | Medium | Two buckets belonging to other projects: encryption, versioning, TLS-only policy, logging. |
| IAM password policy | 7 (6 medium, 1 low) | Medium | Length, symbol, number, uppercase, reuse and expiry rules are not met. Account-wide change: show and ask first. |
| Account settings and other | 6 (3 medium, 3 low) | Medium | Security contact details, RDS event subscriptions, backup vaults, support plan. |
| Default VPC network ACL and VPC | 4 (1 high, 3 medium) | High | The default VPC's default ACL allows all inbound traffic; the default VPC is not used by the stack. |
| AI services not in use | 6 (2 medium, 4 low) | Medium | Bedrock and SageMaker checks. Not applicable to this stack. |
| S3 account public access block | 1 (high) | High | The account-wide block is off. Account-wide change: show and ask first. |

## 5. Findings introduced by the fixes

Fixes add resources, and the new resources fail some checks. They are listed,
not hidden.

| Fix | New findings | Why they are acceptable |
|------------------|------------------------------------------|----------------------------------------|
| ALB access-log bucket | Prowler 8 rows: `s3_bucket_cross_account_access` (high), KMS, MFA delete, versioning, server access logging (medium), replication, event notifications, object lock (low). Checkov CKV_AWS_18 (directory only), CKV_AWS_21, CKV_AWS_144, CKV_AWS_145, CKV2_AWS_62 | A log-only bucket with a 30-day expiry. The cross-account row is the load-balancer service principal that ALB logs require. ALB logs support SSE-S3 only. |
| RDS log exports | Four log-group rows (KMS, retention on the two new groups); Checkov CKV_AWS_158 and CKV_AWS_338 | AWS-managed encryption; short retention to limit cost. |
| RDS enhanced monitoring | Two rows on `RDSOSMetrics` (created by AWS) | Not in the Terraform code. |
| Query-logging parameter group | Checkov CKV2_AWS_69, plan scan only. It passed in both baseline scans | The group does not set `rds.force_ssl`, so Checkov cannot see the default. Whether TLS was enforced was not checked live. Cheap fix for later: set `rds.force_ssl = 1` explicitly. |

Arithmetic: Prowler 126 - 6 + 14 = 134. Checkov Terraform 18 - 4 + 9 = 23, and
plan 20 - 4 + 9 = 25.

## 6. Could not evaluate

- **Six manual-review rows** (both scans): account contact details, security
  contact, security questions, two KMS enclave checks and Trusted Advisor
  errors. All need a human or a console check.
- **Service control policy.** Before the after scan, an organization policy
  denied the Elastic Load Balancing call `DescribeLoadBalancerAttributes` to the
  admin user (observed 2026-11-19). The audit role could read the same setting:
  `elbv2_logging_enabled` passed in the after scan. The reason for the
  difference was not investigated. `ec2:DescribeInstances` was expected to be
  denied by the same kind of policy, but it succeeded as the admin user (the
  account has no instances); it was not tested as the audit role.
- **RDS-managed secret resource policy.** Prowler could not tell "no policy"
  from "no access". Read as the admin user it showed no policy.
- **No permission errors** were logged in either Prowler run. That does not
  prove nothing was denied.
- **Two rows** (both scans) are in `us-east-1`: Trusted Advisor, served from
  there.
- **Organization-level services** (central CloudTrail, GuardDuty, Security Hub)
  were not checked.

## 7. Method

- **Access.** A read-only role (`SecurityAudit`, `ViewOnlyAccess` and Prowler's
  read-only additions), assumed with MFA for one hour; credentials kept in the
  shell only. Region `ap-southeast-2` only.
- **Prowler 5.49.0**, image pinned by digest, `aws --region ap-southeast-2`
  with CSV, JSON-OCSF and HTML output. All checks run; the CIS AWS benchmark
  (`cis_7.0_aws`) is a mapping, not a filter. 668 checks ran in the baseline.
- **Checkov 3.4.5**, image pinned by digest: the Terraform directory, a plan
  JSON from a full staging plan, and the `github_actions` framework.
- **Same commands, versions and scope** for both scans. The only differences
  are the date, the label and the code commit (`6a87780` before, `9f8c0be`
  after). Both plan scans were made when the plan was a no-op against the
  deployed staging stack.
- **Owner rule** for Prowler rows: the stack's state bucket is its own group; a
  row is the audited stack's if it mentions the project name, or is the staging
  VPC or its default network ACL; `RDSOSMetrics` is shown separately; the rest
  is account level or other projects.
- **Severities.** Prowler's own. Checkov has none: rated from the matching
  Prowler check, or by me where there is none (CKV2_AWS_30, CKV_AWS_260,
  CKV_AWS_354, CKV_AWS_394, CKV_GHA_7, CKV2_AWS_69).
- **Staging was deployed** for the scans and destroyed afterwards. Production
  was not deployed; its differences (multi-AZ, deletion protection, two NAT
  gateways, a broader CI apply role) are covered by the code scans only.

## 8. Limits

- A point-in-time scan of one region. Not a penetration test and not a
  compliance certification.
- Staging only. Production's CI apply role still has its earlier, broader
  policy, so Prowler flags it. Decided to report, not change.
- The account-level fixes (S3 account public access block, IAM password
  policy, default network ACL) are recommendations, not changes.
- Checkov findings are not severity-ranked by the tool. The ratings here are
  matched or judged, and say which.
- Prowler row counts are results per resource. Do not compare them with check
  counts.
- The RDS Extended Support fix was attempted and reverted; it is **not** fixed.
- Counts from ad-hoc scans are not used. Only the two saved scan sets are.

## 9. Fix log (audited stack, one commit per change)

| Commit | Change |
|----------------|------------------------------------------------------------------------------------|
| `3c792fb` | CI apply role IAM writes limited to the environment's service roles |
| `e51ea0e` | RDS logs exported to CloudWatch (CKV_AWS_129) |
| `e101810` | RDS query logging through a parameter group (CKV2_AWS_30) |
| `5b0232f`, `056cb9c` | RDS enhanced monitoring (CKV_AWS_118); the second fixes the PassRole condition |
| `5403238` | ALB access logs to a locked S3 bucket (CKV_AWS_91) and the apply role's S3 permissions |
| `5c52501` | Confused-deputy conditions on the ECS execution, ECS task and VPC flow-log roles |
| `a9d7511` | GitHub Actions pinned to commit SHAs (hand-found) |
| `315c976`, `af507da`, `9f8c0be` | RDS Extended Support attempt and its revert; no net change |

## 10. Cost

The scans are free. The staging stack cost an estimated $3 a day (about $93 a month) while it ran
(from 2026-11-17 to 2026-11-19) and was destroyed after the after scans. Nothing is
left running. One manual database snapshot of the production environment was
kept by decision.

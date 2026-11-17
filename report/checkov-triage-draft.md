# Checkov triage (draft, before baseline)

Source: `reports/2026-11-18-baseline/` (Checkov 3.4.5 and Prowler 5.49.0),
project 1 code at `7dc21e5` (scanned at `6a87780`, docs-only on top, 0
uncommitted files). Checkov: Terraform 195 passed / 18 failed, GitHub Actions
118 / 2, plan JSON 152 / 20. Prowler: see the Prowler section at the end.

**Severity**: Checkov open source gives none. Every severity below is my own
rating (impact for this sample stack). It is to be replaced by the matching
Prowler check's severity where one exists, once the Prowler baseline is saved.
Say which in the report.

Buckets: **Fix now**, **Fix later**, **Accepted** (with reason), **N/A / could
not evaluate**.

## Terraform directory scan (18 failures)

| Check | Resource | Severity (mine) | Bucket | Reason / fix |
|---|---|---|---|---|
| CKV_AWS_129 | rds_postgres `this` | Medium | Fix now | Enable `enabled_cloudwatch_logs_exports = ["postgresql","upgrade"]`. Small CloudWatch cost. |
| CKV2_AWS_30 | rds_postgres `this` | Medium | Fix now | Query logging: parameter group `log_statement` / `log_min_duration_statement`. Same change set as CKV_AWS_129. |
| CKV_AWS_118 | rds_postgres `this` | Medium | Fix now | `monitoring_interval = 60` plus a monitoring role. |
| CKV_AWS_91 | ecs_service ALB | Medium | Fix now | Access logs to a locked S3 bucket (block public access, SSE, lifecycle). A few cents. |
| CKV_AWS_2, CKV_AWS_103, CKV2_AWS_20, CKV_AWS_378 | ALB listener / target group | Medium (High on a real client app) | Accepted | HTTPS needs a domain and ACM certificate, out of scope. Traffic is plain HTTP, so anything sensitive would be readable on the path. Next step: domain, ACM, 443 listener, 80 to 443 redirect. |
| CKV_AWS_260 | ALB SG, port 80 from 0.0.0.0/0 | Low | Accepted | It is the public entry point. Goes away only with a non-public design. |
| CKV2_AWS_28 | ALB | Low | Accepted | WAF adds standing cost and is out of scope. Recommend for a real client. |
| CKV_AWS_65 | ECS cluster | Low | Accepted (staging); prod sets `container_insights = true` | Cost. |
| CKV_AWS_336 | ECS task definition | Medium | Fix later | Writable root filesystem. README says the sample nginx needs it. Can be fixed with `readonlyRootFilesystem` plus tmpfs volumes for the paths nginx writes. Confirmed real by reading the code; the plan scan cannot see it (see limits). |
| CKV_AWS_338 | service log group, VPC flow log group | Low | Accepted | Retention is per environment: staging 14 days (flow logs), prod 90, cost. Both are under the 1-year the check wants. |
| CKV_AWS_158 | service log group, VPC flow log group | Low | Accepted | AWS-managed encryption in use; a CMK adds cost and key-policy upkeep. |
| CKV_AWS_354 | RDS Performance Insights | Low | Accepted | Same reason as CKV_AWS_158. |
| CKV_AWS_394 | `aws_availability_zones` data source | Info | Accepted | Style check on a data source. The code filters opt-in and slices by `az_count`, so only AZ order could change on a later plan. Not a deployed-resource risk. |

Tally (counting failures, so the two log-group checks count twice): Fix now 4
(CKV_AWS_129, CKV2_AWS_30, CKV_AWS_118, CKV_AWS_91); Fix later 1
(CKV_AWS_336); Accepted 13 (HTTPS group 4, CKV_AWS_260, CKV2_AWS_28,
CKV_AWS_65, CKV_AWS_338 x2, CKV_AWS_158 x2, CKV_AWS_354, CKV_AWS_394).
4 + 1 + 13 = 18, matching the scan.

## GitHub Actions scan (2 failures)

| Check | Workflow | Severity (mine) | Bucket | Reason |
|---|---|---|---|---|
| CKV_GHA_7 | `destroy.yml` | Low | Accepted | `workflow_dispatch` inputs: `environment` is a choice of staging/prod, `confirm` is a typed confirmation. Inputs select the environment, they do not change build output. Not in project 1's README. |
| CKV_GHA_7 | `terraform.yml` | Low | Accepted | Same: `environment` is a choice input. |

Found by reading, not by a scanner (do not count in the tables): all actions
are pinned to tags (`@v4`, `@v3`, `@v12`), not commit SHAs. This is the
GOALS.md candidate fix; both Checkov and Prowler are silent on it.

## Plan JSON scan, extra findings (staging values)

These fail only in the plan scan (staging tfvars). They are tolerated in
staging by design; prod sets the safe value in `envs/prod.tfvars`.

| Check | Resource | Severity (mine) | Bucket | Reason |
|---|---|---|---|---|
| CKV_AWS_150 | ALB | Low | Accepted (staging) | Deletion protection off so staging destroys cleanly. Prod: `alb_deletion_protection = true`. |
| CKV_AWS_293 | RDS | Low | Accepted (staging) | `db_deletion_protection = false`. Prod: true. |
| CKV_AWS_157 | RDS | Low | Accepted (staging) | `db_multi_az = false`. Prod: true. |

The plan scan has 20 failures. CKV_AWS_336 fails in it too (baseline plan is a
no-op against the deployed staging stack, so the container definition is
known). CKV_AWS_394 and CKV_AWS_354 do not appear in the plan scan. Not yet
diffed line by line against the directory scan: do that before claiming the
rest are identical.

## Limits to put in the report

- Plan JSON cannot evaluate attributes unknown before apply. The plan was a
  no-op against deployed staging, so nothing was unknown and CKV_AWS_336 fails
  in it. A plan made before the first apply would not show that.
- CKV_AWS_394 is not evaluated in the plan scan (data sources are reads).
- The two scans are not added together. Each is reported on its own.
- Directory scan and plan scan cover different resource sets and applicability.

## Decisions (2026-11-17)

1. Fix now confirmed: CKV_AWS_129, CKV2_AWS_30, CKV_AWS_118, CKV_AWS_91.
   One commit per check ID in project 1; 129 and CKV2_AWS_30 touch the same
   resources but still get one commit each.
2. CKV_AWS_336 is **Fix later**, not accepted as in project 1's README. Plan:
   `readonlyRootFilesystem = true` plus tmpfs/volume mounts for the paths nginx
   writes. The report should say this differs from the README.
3. HTTPS group stays **Accepted** at Medium. The report notes a real client's
   public app would rate it High and gives the domain/ACM/443/redirect path.
4. Pinning GitHub Actions to commit SHAs is added to **Fix now**. It is a
   hand-found improvement, not a Checkov or Prowler result, so it has no check
   ID: the commit names the change, and the before/after table lists it
   separately from scanner counts.

Updated tally for the Terraform directory scan: Fix now 4, Fix later 1,
Accepted 13 (unchanged). Plus one hand-found fix (action SHA pinning).

---

# Prowler baseline triage (draft)

Source: `reports/2026-11-18-baseline/prowler/` (Prowler 5.49.0, region
`ap-southeast-2`, 668 checks executed, no `--compliance` flag, CIS 7.0 read
from the COMPLIANCE column). Severities are Prowler's own.

| Status | Critical | High | Medium | Low | Total |
|---|---|---|---|---|---|
| FAIL | 1 | 23 | 72 | 30 | 126 |
| PASS | 48 | 132 | 77 | 12 (+1 info) | 270 |
| MANUAL | 0 | 1 | 5 | 0 | 6 |

All buckets below are **proposed**; none is decided unless it appears in the
decisions list above. Counts are result rows (one per resource), not checks.

Split by owner (by resource name, measured from `prowler.csv`):
- Project 1 resources (`ecs-foundation-*`): 25 FAIL rows (7 high, 15 medium,
  3 low).
- Project 1 state bucket `joheee-ecs-foundation-tfstate`: 9 rows (5 medium,
  4 low). Created by hand, outside Terraform.
- Everything else (account level and other projects): the remaining rows.

## Project 1's own findings

| Prowler check | Sev | Resource | Same as Checkov | Proposed bucket | Note |
|---|---|---|---|---|---|
| iam_inline_policy_allows_privilege_escalation | High | staging and prod `github-apply` roles, policy `terraform-apply` | no | Fix now (candidate) | GOALS candidate "tighter IAM statements". Read the policy before choosing the change. The apply roles survive destroy, so prod shows up even with only staging deployed. |
| iam_role_cross_service_confused_deputy_prevention | High | staging ECS execution, ECS task, VPC flow-logs roles | no | Fix now (candidate) | Add `aws:SourceAccount` / `aws:SourceArn` conditions to the trust policies. Cheap. Neither Checkov check nor README covers it. |
| ecs_task_definitions_containers_readonly_access | High | `ecs-foundation-staging:5` | CKV_AWS_336 | Fix later | Same finding, see decision 2. Prowler rates it High, my draft rating was Medium: use Prowler's. |
| ecs_task_definitions_logging_block_mode | Low | `ecs-foundation-staging:5` | no | Accepted (to confirm) | Not looked at yet. |
| rds_instance_protected_by_backup_plan | High | staging RDS | no | Accepted (to confirm) | An AWS Backup plan adds cost. Check what the RDS automated backup retention is before accepting. |
| secretsmanager_has_restrictive_resource_policy | High | RDS-managed master secret | no | Accepted or N/A (to confirm) | Secret is created by `manage_master_user_password`. Check whether a resource policy can be attached to it. |
| rds_instance_integration_cloudwatch_logs | Med | staging RDS | CKV_AWS_129 | Fix now | Decided. |
| rds_instance_enhanced_monitoring_enabled | Low | staging RDS | CKV_AWS_118 | Fix now | Decided. Prowler rates it Low. |
| elbv2_logging_enabled | Med | staging ALB | CKV_AWS_91 | Fix now | Decided. |
| elbv2_ssl_listeners | Med | staging ALB | CKV_AWS_2 group | Accepted | Decision 3. |
| elbv2_waf_acl_attached | Med | staging ALB | CKV2_AWS_28 | Accepted | Cost. |
| elbv2_deletion_protection | Med | staging ALB | CKV_AWS_150 | Accepted (staging) | Prod sets it true. |
| rds_instance_deletion_protection, rds_instance_multi_az | Med | staging RDS | CKV_AWS_293, CKV_AWS_157 | Accepted (staging) | Prod sets both true. |
| rds_instance_extended_support | Med | staging RDS | no | Fix later (to confirm) | Likely the engine version is near end of standard support. Check the version before rating. |
| rds_instance_non_default_port | Low | staging RDS | no | Accepted | Fails because the instance uses the default port 5432. Low value: the port is not what protects it. Confirm from the SG that it is not internet-reachable. |
| ecs_cluster_container_insights_enabled | Med | staging cluster | CKV_AWS_65 | Accepted | Cost. |
| cloudwatch_log_group_kms_encryption_enabled, cloudwatch_log_group_retention_policy_specific_days_enabled | Med | staging service and flow-log groups | CKV_AWS_158, CKV_AWS_338 | Accepted | Prowler rates these Medium, my draft rating was Low. |

CKV_AWS_260 (ALB SG on port 80), CKV_AWS_354 and CKV_AWS_394 have no matching
Prowler row.

Observation to check: a third log group, `/aws/ecs/containerinsights/ecs-foundation-prod/...`,
is in the log-group findings. Prod is not deployed for this audit, so it is
probably left over from an earlier prod run. Confirm and, if so, report it as a
leftover, not a project 1 defect.

## Project 1 state bucket (hand-made, outside Terraform)

`joheee-ecs-foundation-tfstate` fails: KMS encryption, MFA delete, object
versioning, secure transport policy, access logging (medium), and cross-region
replication, event notifications, lifecycle, object lock (low). Proposed:
versioning and the secure-transport policy are **Fix later** (state recovery
and TLS-only are the ones a client would care about; versioning off on a state
bucket means no recovery from a bad state write). The rest are **Accepted**
for a one-person sample.

## Account level and other projects (separate section of the report)

| Prowler check | Sev | Resource | Proposed bucket | Note |
|---|---|---|---|---|
| iam_aws_attached_policy_no_administrative_privileges | Critical | `AdministratorAccess` attached | Report only | Account-level. Who it is attached to decides whether it is a fix or an accepted risk. |
| iam_group_administrator_access_policy | High | group `cloud-engineer` | Report only | Admin policy on a group. |
| iam_user_hardware_mfa_enabled, iam_user_with_temporary_credentials | High | users `upwork-project`, `upwork-pgbackrest-demo` | Report only | `upwork-project` has a virtual MFA, not hardware; `upwork-pgbackrest-demo` has no MFA at all. Both have long-lived credentials with access beyond IAM and STS (Prowler's wording). Do not touch these users. |
| iam_role_cross_service_confused_deputy_prevention | High | `AccountFullAccessRole` | Report only | Not project 1. |
| cloudtrail_multi_region_enabled and 4 other CloudTrail rows | High to Low | account | Report only | No trail seen. Day-1 question about central CloudTrail is still open. |
| s3_account_level_public_access_blocks | High | account | Fix now (ask first) | Account-wide change: show the exact change and ask. |
| iam_password_policy_* (7 rows) | Med/Low | account | Fix now (ask first) | Account-wide change: show and ask. |
| ec2_networkacl_allow_ingress_any_port, ..._tcp_port_22, ..._tcp_port_3389 | High/Med | 2 network ACLs | Report only | Find out which VPC they belong to (probably not project 1) before assigning. |
| guardduty_*, securityhub_*, config_*, inspector2_is_enabled, macie_is_enabled | High/Med | account | Report only | Out of scope (GOALS). Recommend only. |
| s3_bucket_* | Med/Low | `tictactoe-tfstate-001`, `upwork-pgbackrest` | Report only | Other projects' buckets (4 and 3). |
| cloudwatch_log_metric_filter_* and cloudwatch_changes_* (15 rows) | Med | account | Report only | CIS monitoring alarms, need CloudTrail to a log group first. |
| bedrock_*, sagemaker_*, drs_job_exist, ssmincidents_enabled_with_plans, networkfirewall_in_all_vpc, vpc_* and others | Med/Low | account | Report only or N/A | Services not in use. Say "not applicable to this stack" in the report. |

The 6 FAIL rows tied to `iam_role_access_not_stale_to_bedrock` /
`iam_user_access_not_stale_to_bedrock` are about unused Bedrock access: report
only.

## Could not evaluate (Prowler MANUAL, 6 rows)

`account_maintain_current_contact_details`,
`account_security_contact_information_is_registered`,
`account_security_questions_are_registered_in_the_aws_account`,
`kms_key_enclave_attestation_unknown_image`,
`kms_key_enclave_debug_attestation_detected`,
`trustedadvisor_errors_and_warnings`. All need a human or a console check.

## Coverage notes (measured on 2026-11-18)

- `permission-errors.txt` is empty and the log has no error lines. That does
  not prove nothing was denied.
- The CSV has 27 EC2 checks and no `ec2_instance_*` check. There are 0 EC2
  instances in `ap-southeast-2` (`describe-instances` as the admin user, not as
  the audit role, returned 0 reservations). It was not denied, so the
  CLAUDE.md and GOALS.md statements about the SCP denying it were not
  confirmed. Not yet tested as the `security-audit` role.
- 2 rows are `us-east-1`: both Trusted Advisor, whose API is served from there.
- Do not call any check passed or failed beyond what is in the CSV.

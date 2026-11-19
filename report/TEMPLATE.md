# AWS Security Audit: <client or system name>

<!--
How to use this template
- Copy it to a new file per engagement. Delete these comment blocks before
  sending.
- Every number comes from a saved scan. Do not type a count you did not
  measure. If a number cannot be measured, write "not measured".
- Redact before sending: account IDs, ARNs that contain account numbers, IP
  addresses, e-mail addresses, and the names of people or other clients'
  systems. Search the file for 12-digit numbers, "arn:aws", "@" and dotted IPs.
- Mark every bucket you have not agreed with the client as (proposed).
-->

| | |
|---|---|
| Client / system | <name and a one-line description> |
| Account | <number of accounts>, account ID redacted. Region(s): <list> |
| Baseline scan | <date>, code at `<commit>` |
| After scan | <date>, code at `<commit>` (delete this row for a report-only audit) |
| Tools | Prowler <version> (<framework mapping>), Checkov <version>, <others> |
| Access | Read-only role assumed with MFA and an external ID; no access keys |

## 1. Summary

<!-- One page for the business owner. Plain words, no tool jargon. -->

**Overall rating:** <low / moderate / high risk>, with one sentence of why.
<!-- The rating is a judgement. Say what it rests on. -->

**Top five risks**, ranked by what each would mean for the business:

1. **<risk>.** <what it means in plain words>. <fixed / recommended / needs a
   decision>.
2. **<risk>.** <...>
3. **<risk>.** <...>
4. **<risk>.** <...>
5. **<risk>.** <...>

**What was fixed:**

| Fix | Closes |
|---|---|
| <change> | <check ID or finding> |

**Before and after, in one line each.** <Totals can go up when fixes add
resources. If they did, say so here and point to section 5.>

## 2. Before and after

<!-- Delete this whole section for a report-only audit. -->

### <Live-account tool> (<scope>)

| Failed rows | Critical | High | Medium | Low | Total |
|---|---|---|---|---|---|
| Before | | | | | |
| After | | | | | |

Passed rows <before> and <after>; manual-review rows <before> and <after>.
Counts are result rows (one per resource), not distinct checks.

By owner (use the same rule in both scans, see Method):

| Group | Before | After |
|---|---|---|
| Audited system | | |
| Resources created by AWS as a side effect of a fix | | |
| Hand-made resources outside the code (for example a state bucket) | | |
| Account level and other projects | | |

<!-- The "other projects" row should be identical before and after. If not,
something outside the audited system changed. Find out why. -->

By service, failed rows before and after: <service> <n> to <n>, ...

### <Code tool> (<scope>)

<!-- Open-source Checkov gives no severities. Rate each finding from the
matching live-scan check, otherwise by hand, and say which. -->

| Scan | Passed before | Failed before | Passed after | Failed after |
|---|---|---|---|---|
| <directory / plan / pipeline> | | | | |

Failures by rated severity:

| Scan | Rating | Before | After |
|---|---|---|---|
| | High | | |
| | Medium | | |
| | Low | | |

Closed: <check IDs>. Introduced by fixes: <n> (section 5).

<!-- Note any scan pair that covers different things (for example a plan scan
and a directory scan) and do not add them together. -->

## 3. Findings on the audited system

Status: **Fixed**, **Fix later**, **Accepted** (with the reason) or **Could not
evaluate**. Mark buckets *(proposed)* until the client agrees.

### Critical and High

| Finding | Evidence (redacted) | Status | Impact and fix |
|---|---|---|---|
| <check ID and title> | <what the scan saw> | <bucket> | <what it means for the business; the exact fix> |

### Medium

| Finding | Status | Notes |
|---|---|---|
| | | |

### Low

| Finding | Status | Notes |
|---|---|---|
| | | |

### Resources outside the code

<!-- Hand-made resources (for example a Terraform state bucket) get their own
short section: rows, proposed buckets, reason. -->

## 4. Account-level findings (not the audited system)

<!-- Findings that belong to the account or to other projects. Report them,
do not fix them unless the client asked. Group by theme. -->

| Theme | Rows | Highest | What it means |
|---|---|---|---|
| <logging and detection> | | | |
| <IAM: admin access, MFA, credentials> | | | |
| <S3 account public access block> | | | |
| <password policy> | | | |
| <other> | | | |

## 5. Findings introduced by the fixes

<!-- Fixes add resources, and new resources can fail checks. List them. Do not
skip them to make the totals look better. -->

| Fix | New findings | Why they are acceptable (or not) |
|---|---|---|
| | | |

Arithmetic: <before> - <closed> + <introduced> = <after>, for each scan.

## 6. Could not evaluate

<!-- A check that errors or needs a human is never "passed". -->

- **Manual-review rows:** <list>.
- **Permission denials observed:** <API, who was denied, what was observed. Say
  "observed", not why, unless you confirmed the cause>.
- **Checks that could not be evaluated as the audit role:** <list>.
- **Not checked:** <for example organization-level services>.

## 7. Method

- **Access.** <role, policies, how it was assumed, session length, where the
  credentials were kept>. Region(s): <list>.
- **<Live-account tool and version>**, image pinned by digest, command:
  `<exact command>`. <Checks that ran.>
- **<Code tool and version>**, image pinned by digest: <scans run>.
- **Same commands, versions and scope** for both scans. Differences: the date,
  the label and the code commit (`<before>` and `<after>`).
- **Owner rule** for live-scan rows: <how you decided a row belongs to the
  audited system>.
- **Severities.** <Tool's own, or matched, or judged; list the judged ones>.
- **What was deployed for the scans** and whether it was destroyed afterwards.

## 8. Limits

- A point-in-time scan of <regions>. Not a penetration test and not a
  compliance certification.
- <Anything not scanned: other environments, other accounts, other regions.>
- <Account-level items that are recommendations, not changes, and why.>
- <Fixes that were attempted and did not work: say they are not fixed.>
- Only saved scan sets are used for counts.

## 9. Fix log

| Commit | Change |
|---|---|
| `<hash>` | <one change, naming the check ID it closes> |

## 10. Cost

<Scans are free. State any standing cost the audit added, how long it ran, and
whether anything is left running.>

<!--
Before sending
- [ ] Every number traces to a saved scan; none typed from memory.
- [ ] Before and after used the same commands, versions and scope, and the
      report records them.
- [ ] Findings introduced by fixes are listed (section 5).
- [ ] Anything attempted and not fixed says so.
- [ ] No account IDs, ARNs with account numbers, IPs, e-mail addresses or
      other clients' names remain.
- [ ] Buckets not yet agreed are marked (proposed).
- [ ] The audit role, session credentials and any staging resources are removed
      or expired, and the client is told how to delete the role.
-->

#!/usr/bin/env bash
# Prowler AWS scan: CIS benchmark plus all checks, region ap-southeast-2.
# Output (CSV, JSON-OCSF, HTML) goes to reports/<date>-<label>/prowler/.
#
# Usage: scans/prowler.sh --label before --project ../AwsEcsFoundationTerraform
#
# Credentials: the assumed security-audit role session, in the environment
# (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN). Never in a file.
set -euo pipefail

# Pinned by digest. To upgrade: change tag and digest together, then re-run
# both the before and after scans.
PROWLER_VERSION="5.49.0"
PROWLER_IMAGE="prowlercloud/prowler@sha256:0113d8ee9d42674d1b1baf3b64505835fd2f14b0bb0ab2bbe5d4a52f49ff3d22"
REGION="ap-southeast-2"
CIS_FRAMEWORK="cis_7.0_aws"

usage() {
  echo "Usage: $0 --label <label> --project <path to project 1 checkout> [--date YYYY-MM-DD]" >&2
  exit 2
}

label="" project="" date_str="$(date +%F)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label="${2:-}"; shift 2 ;;
    --project) project="${2:-}"; shift 2 ;;
    --date) date_str="${2:-}"; shift 2 ;;
    -h | --help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "--label is required (letters, digits, . _ -)" >&2; usage; }
[[ -d "$project" ]] || { echo "--project must be a directory" >&2; usage; }
[[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "--date must be YYYY-MM-DD" >&2; usage; }
for v in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do
  [[ -n "${!v:-}" ]] || { echo "$v is not set. Assume the security-audit role with MFA first." >&2; exit 2; }
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out_dir="$repo_root/reports/$date_str-$label/prowler"
[[ ! -e "$out_dir" ]] || { echo "$out_dir already exists. Use a new --label or --date." >&2; exit 1; }
mkdir -p "$out_dir"

project_commit="$(git -C "$project" rev-parse HEAD 2>/dev/null || echo unknown)"
project_dirty="$(git -C "$project" status --porcelain 2>/dev/null | wc -l)"

cmd=(docker run --rm
  --user "$(id -u):$(id -g)"
  -e HOME=/tmp
  -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN
  -v "$out_dir:/out"
  "$PROWLER_IMAGE"
  aws
  --region "$REGION"
  --compliance "$CIS_FRAMEWORK"
  --output-formats csv json-ocsf html
  --output-directory /out
  --output-filename prowler
  --no-banner)

# Record exactly what ran. Values of the credentials are never written.
{
  echo "tool: prowler $PROWLER_VERSION"
  echo "image: $PROWLER_IMAGE"
  echo "date: $date_str"
  echo "label: $label"
  echo "region: $REGION"
  echo "compliance: $CIS_FRAMEWORK (plus all checks)"
  echo "project_1_commit: $project_commit (uncommitted changes: $project_dirty files)"
  echo "command: ${cmd[*]}"
} > "$out_dir/meta.txt"

echo "Prowler $PROWLER_VERSION, region $REGION, output $out_dir"

# Prowler exits 3 when it finds failures. That is a normal result, not an error.
set +e
"${cmd[@]}" 2>&1 | tee "$out_dir/prowler.log"
rc="${PIPESTATUS[0]}"
set -e
echo "exit code: $rc" >> "$out_dir/meta.txt"
if [[ "$rc" -ne 0 && "$rc" -ne 3 ]]; then
  echo "Prowler failed with exit code $rc, see $out_dir/prowler.log" >&2
  exit "$rc"
fi

# Permission errors show up in the log, not as FAIL. Keep them for the
# "could not evaluate" section of the report.
grep -iE 'AccessDenied|UnauthorizedOperation|not authorized|explicit deny' "$out_dir/prowler.log" \
  > "$out_dir/permission-errors.txt" || true
echo "permission error lines: $(wc -l < "$out_dir/permission-errors.txt") (see permission-errors.txt)"

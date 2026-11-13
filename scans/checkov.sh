#!/usr/bin/env bash
# Checkov scans on project 1: Terraform directory, plan JSON (optional) and
# GitHub Actions workflows. Each writes CLI text, JSON and SARIF to
# reports/<date>-<label>/checkov-<name>/. No AWS access needed.
#
# Usage: scans/checkov.sh --label before --project ../AwsEcsFoundationTerraform \
#                         [--plan-json path/to/plan.json]
#
# Plan JSON: terraform plan -out=tfplan && terraform show -json tfplan > plan.json
# (run in project 1; needs AWS access, so it is not automated here). Use the same
# scope for before and after: both with a plan file or both without.
set -euo pipefail

# Pinned by digest. To upgrade: change tag and digest together, then re-run
# both the before and after scans.
CHECKOV_VERSION="3.4.5"
CHECKOV_IMAGE="bridgecrew/checkov@sha256:122602cf32cc72286155d39f1f234b7b594818f7b8d7fdf490701620e521368b"

usage() {
  echo "Usage: $0 --label <label> --project <path to project 1 checkout> [--plan-json <file>] [--date YYYY-MM-DD]" >&2
  exit 2
}

label="" project="" plan_json="" date_str="$(date +%F)"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label="${2:-}"; shift 2 ;;
    --project) project="${2:-}"; shift 2 ;;
    --plan-json) plan_json="${2:-}"; shift 2 ;;
    --date) date_str="${2:-}"; shift 2 ;;
    -h | --help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "--label is required (letters, digits, . _ -)" >&2; usage; }
[[ -d "$project" ]] || { echo "--project must be a directory" >&2; usage; }
[[ -z "$plan_json" || -f "$plan_json" ]] || { echo "--plan-json file not found" >&2; usage; }
[[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "--date must be YYYY-MM-DD" >&2; usage; }

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_dir="$repo_root/reports/$date_str-$label"
project="$(cd "$project" && pwd)"
mkdir -p "$run_dir"

project_commit="$(git -C "$project" rev-parse HEAD 2>/dev/null || echo unknown)"
project_dirty="$(git -C "$project" status --porcelain 2>/dev/null | wc -l)"

# run_checkov <name> <volume mount> <checkov args...>
# Checkov exits 1 when checks fail. That is a normal result, not an error.
run_checkov() {
  local name="$1" mount="$2"
  shift 2
  local out_dir="$run_dir/checkov-$name"
  [[ ! -e "$out_dir" ]] || { echo "$out_dir already exists. Use a new --label or --date." >&2; exit 1; }
  mkdir -p "$out_dir"

  local cmd=(docker run --rm
    --user "$(id -u):$(id -g)"
    -e HOME=/tmp
    -v "$out_dir:/out"
    -v "$mount"
    "$CHECKOV_IMAGE"
    "$@"
    --output cli --output json --output sarif
    --output-file-path /out
    --compact)

  {
    echo "tool: checkov $CHECKOV_VERSION"
    echo "image: $CHECKOV_IMAGE"
    echo "date: $date_str"
    echo "label: $label"
    echo "scan: $name"
    echo "project_1_commit: $project_commit (uncommitted changes: $project_dirty files)"
    echo "command: ${cmd[*]}"
  } > "$out_dir/meta.txt"

  echo "Checkov $CHECKOV_VERSION: $name -> $out_dir"
  local rc=0
  "${cmd[@]}" > "$out_dir/checkov.log" 2>&1 || rc=$?
  echo "exit code: $rc" >> "$out_dir/meta.txt"
  if [[ "$rc" -ne 0 && "$rc" -ne 1 ]]; then
    echo "Checkov $name failed with exit code $rc, see $out_dir/checkov.log" >&2
    exit "$rc"
  fi
}

# Mount the project read-only; Checkov only reads it.
run_checkov terraform "$project:/src:ro" -d /src --framework terraform
run_checkov github-actions "$project:/src:ro" -d /src --framework github_actions

if [[ -n "$plan_json" ]]; then
  plan_abs="$(cd "$(dirname "$plan_json")" && pwd)/$(basename "$plan_json")"
  run_checkov plan "$plan_abs:/plan/plan.json:ro" -f /plan/plan.json --framework terraform_plan
else
  echo "No --plan-json given: plan JSON scan skipped. Record this in the report." >&2
  echo "plan scan: skipped (no --plan-json)" > "$run_dir/checkov-plan-skipped.txt"
fi

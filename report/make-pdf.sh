#!/usr/bin/env bash
# Render report/audit-report.md to report/audit-report.pdf with pandoc in Docker.
# No AWS access needed. The image is pinned by digest (pandoc 3.14).
# Usage: report/make-pdf.sh [input.md [output.pdf]]
set -euo pipefail

PANDOC_IMAGE="pandoc/latex@sha256:8077a199a829a05e19b61a0de7e447eb797e2edbec925412dfc9694d1aaeb4dd"

report_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input="${1:-audit-report.md}"
output="${2:-audit-report.pdf}"

[[ -f "$report_dir/$input" ]] || { echo "$report_dir/$input not found" >&2; exit 2; }

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$report_dir:/data" \
  -w /data \
  "$PANDOC_IMAGE" \
  "$input" \
  --from markdown \
  --pdf-engine=xelatex \
  --output "$output" \
  -V geometry:a4paper,margin=18mm \
  -V fontsize=10pt \
  -V colorlinks=true \
  --include-in-header=pdf-header.tex

echo "wrote $report_dir/$output"

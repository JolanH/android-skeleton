#!/usr/bin/env bash
# Constraint checks (canonical list and reasons: CONSTRAINTS.md). Everything runs in Docker.
#   ./scripts/check.sh fast   floor guard + secrets in pending changes + ktlint + unit tests (edit loop)
#   ./scripts/check.sh task   fast + lint + Kover rules + changed-line coverage (task end)
#   ./scripts/check.sh full   task + debug APK + secrets over all history             (CI / before review)
# Env: CHECK_BASE (default develop) = branch the diff is scoped against.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${CHECK_BASE:-develop}"
NODE_IMAGE="node:22.11.0-bookworm"
GITLEAKS_IMAGE="zricethezav/gitleaks:v8.21.2"
STAGE="${1:-fast}"

in_node() {
  docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$ROOT":/repo -w /repo "$NODE_IMAGE" node "$@"
}
gitleaks() {
  docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$ROOT":/repo -w /repo "$GITLEAKS_IMAGE" "$@"
}
step() { printf '\n== %s\n' "$*"; }

fast() {
  step "floor guard (diff vs $BASE)"
  in_node scripts/floor-guard.mjs --base "$BASE"
  step "secrets in pending changes (gitleaks, redacted)"
  gitleaks git /repo --pre-commit --redact --no-banner
  gitleaks git /repo --pre-commit --staged --redact --no-banner
  step "ktlint"
  "$ROOT/dev.sh" ktlintCheck
  step "unit tests (never skipped, at any stage)"
  "$ROOT/dev.sh" testDebugUnitTest
}

task() {
  fast
  step "Android lint + Kover report"
  "$ROOT/dev.sh" lintDebug koverXmlReportDebug
  step "coverage: changed lines >= 80% (vs $BASE), domain/ >= 90%"
  in_node scripts/changed-coverage.mjs --base "$BASE" --min 80 --package-min com/example/skeleton/domain=90
}

full() {
  task
  step "debug APK"
  "$ROOT/dev.sh" assembleDebug
  step "secrets over full git history (gitleaks, redacted)"
  gitleaks git /repo --redact --no-banner
}

case "$STAGE" in
  fast) fast ;;
  task) task ;;
  full) full ;;
  *) echo "usage: $0 fast|task|full" >&2; exit 2 ;;
esac
printf '\ncheck %s: OK\n' "$STAGE"

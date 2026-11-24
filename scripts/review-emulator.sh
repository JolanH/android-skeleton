#!/usr/bin/env bash
# Human-run visual review (CONSTRAINTS.md P3). Not part of check.sh, CI or any agent workflow.
# Builds the debug APK, boots the Pixel 8 / API 34 emulator and opens it in the browser (noVNC)
# so the supervisor can try the app by hand. Needs /dev/kvm. Ctrl+C stops it.
#   ./scripts/review-emulator.sh
# Env: SKELETON_NOVNC_PORT (default 6080).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$ROOT/dev.sh" emulator

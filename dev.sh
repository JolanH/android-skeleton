#!/usr/bin/env bash
# Run Gradle (or any command) inside the Skeleton dev container.
#   ./dev.sh assembleDebug           -> ./gradlew assembleDebug
#   ./dev.sh --shell                 -> interactive bash in the container
#   ./dev.sh --build-image           -> (re)build the image
#   ./dev.sh emulator                -> Pixel 8 / API 34 emulator in the browser (noVNC), needs /dev/kvm
# Works with plain Docker (no compose needed). Caches live in named volumes.
set -euo pipefail

IMAGE="${SKELETON_IMAGE:-skeleton-dev:latest}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

build_image() { docker build -t "$IMAGE" -f "$ROOT/docker/Dockerfile" "$ROOT/docker"; }

if [[ "${1:-}" == "--build-image" ]]; then build_image; exit 0; fi
docker image inspect "$IMAGE" > /dev/null 2>&1 || build_image

if [[ "${1:-}" == "emulator" ]]; then
  PORT="${SKELETON_NOVNC_PORT:-6080}"
  [[ -e /dev/kvm ]] || { echo "emulator needs /dev/kvm (hardware virtualisation)" >&2; exit 1; }
  "$0" assembleDebug
  echo "noVNC: http://localhost:$PORT/vnc.html?autoconnect=true&resize=scale (Ctrl+C to stop)"
  cd "$ROOT"
  exec docker compose --profile emulator up --build --abort-on-container-exit emulator
fi

TTY_FLAGS=()
[[ -t 0 && -t 1 ]] && TTY_FLAGS=(-it)

RUN=(docker run --rm "${TTY_FLAGS[@]}"
  --user "$(id -u):$(id -g)"
  -v "$ROOT":/workspace
  -v skeleton-gradle-cache:/opt/gradle-home
  -e ANDROID_USER_HOME=/opt/gradle-home/android
  -e GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.daemon=false}"
  -w /workspace)

if [[ "${1:-}" == "--shell" ]]; then exec "${RUN[@]}" "$IMAGE" bash; fi
if [[ ! -x "$ROOT/gradlew" ]]; then
  echo "gradlew not found yet (run ./dev.sh --shell and 'gradle wrapper' during bootstrap)" >&2; exit 1
fi
exec "${RUN[@]}" "$IMAGE" ./gradlew "$@"

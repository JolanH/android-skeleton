#!/usr/bin/env bash
# Cuts a release: bumps the version, commits, tags and pushes. FOR THE HUMAN ONLY, never for an AI agent.
#   ./scripts/release.sh 1.1.0             check, bump, commit "Release 1.1.0", tag v1.1.0, push branch + tag
#   ./scripts/release.sh 1.1.0 --dry-run   print what would happen, change nothing
#   ./scripts/release.sh 1.1.0 --skip-check   skip the CI checks of step 3 (not recommended)
#
# What it does, in order:
#   1. refuses to run unless a person is at the keyboard (interactive terminal, no agent environment);
#   2. checks the tree is clean, the version is new and above the current one, and the tag does not exist;
#   3. runs what CI will run, in Docker, before anything is committed or tagged: `./scripts/check.sh full` diffed
#      against the branch as it is on the remote now (like build.yml), the screenshot verification, and the release APK
#      build (like release.yml). A red CI is found here, not after the tag is pushed;
#   4. sets versionName and raises versionCode by 1 in app/build.gradle.kts, commits only that file;
#   5. creates the annotated tag v<version> (the release workflow requires it to match versionName);
#   6. pushes the current branch and the tag. The tag push starts .github/workflows/release.yml.
# Asks you to type the version again before changing anything. If the push fails after the commit and the tag,
# both stay local: fix the cause and run the printed `git push` command.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GRADLE_FILE="app/build.gradle.kts"
REMOTE="origin"

die() {
  printf 'release.sh: %s\n' "$*" >&2
  exit 1
}
step() { printf '\n== %s\n' "$*"; }

# A release publishes under the owner's name and pushes: only a person may start it.
refuse_agents() {
  # Claude Code exports CLAUDECODE=1 to every command it runs; the others cover other agent runners.
  local variable
  for variable in CLAUDECODE CLAUDE_CODE_ENTRYPOINT CODEX_SANDBOX CURSOR_AGENT AIDER_CHAT_HISTORY_FILE; do
    if [[ -n "${!variable:-}" ]]; then
      die "refusing to run: ${variable} is set, this looks like an AI agent. A human must run this script."
    fi
  done
  [[ -t 0 && -t 1 ]] || die "refusing to run without an interactive terminal. A human must run this script."
}

usage() {
  sed -n '2,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

current_version_name() { sed -n 's/^ *versionName = "\(.*\)".*/\1/p' "$ROOT/$GRADLE_FILE"; }
current_version_code() { sed -n 's/^ *versionCode = \([0-9][0-9]*\).*/\1/p' "$ROOT/$GRADLE_FILE"; }

# True when $1 is strictly greater than $2 (both X.Y.Z).
is_newer() {
  local IFS=.
  local -a new old
  read -r -a new <<< "$1"
  read -r -a old <<< "$2"
  local i
  for i in 0 1 2; do
    if ((10#${new[i]} > 10#${old[i]})); then return 0; fi
    if ((10#${new[i]} < 10#${old[i]})); then return 1; fi
  done
  return 1
}

main() {
  local version="" dry_run=0 skip_check=0 arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      --skip-check) skip_check=1 ;;
      -h | --help) usage ;;
      -*) die "unknown option: $arg" ;;
      *) [[ -z "$version" ]] || usage; version="${arg#v}" ;;
    esac
  done
  [[ -n "$version" ]] || usage

  refuse_agents

  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.2.3 (got '$version')"
  local tag="v$version"
  cd "$ROOT"

  local old_name old_code new_code branch
  old_name="$(current_version_name)"
  old_code="$(current_version_code)"
  [[ -n "$old_name" && -n "$old_code" ]] || die "could not read versionName / versionCode in $GRADLE_FILE"
  new_code=$((old_code + 1))
  branch="$(git rev-parse --abbrev-ref HEAD)"

  [[ "$branch" != "HEAD" ]] || die "detached HEAD: check out a branch first"
  [[ -z "$(git status --porcelain)" ]] || die "the working tree is not clean: commit or stash your changes first"
  git remote get-url "$REMOTE" > /dev/null 2>&1 || die "no git remote called '$REMOTE'"
  is_newer "$version" "$old_name" || die "version $version is not above the current $old_name"
  ! git rev-parse -q --verify "refs/tags/$tag" > /dev/null || die "tag $tag already exists locally"
  [[ -z "$(git ls-remote --tags "$REMOTE" "refs/tags/$tag")" ]] || die "tag $tag already exists on $REMOTE"

  # CI diffs a push against the branch as it was on the remote (build.yml), else against origin/develop.
  git fetch --quiet "$REMOTE" || die "could not fetch $REMOTE"
  local base="$REMOTE/$branch"
  git rev-parse -q --verify "refs/remotes/$base" > /dev/null || base="$REMOTE/develop"
  git rev-parse -q --verify "refs/remotes/$base" > /dev/null || die "neither $REMOTE/$branch nor $REMOTE/develop exists to check against"
  git merge-base --is-ancestor "$base" HEAD || die "$branch is behind or has diverged from $base: pull or rebase first"

  step "Release plan"
  printf '  branch       %s (checks run against %s, like CI)\n  versionName  %s -> %s\n  versionCode  %s -> %s\n  commit       "Release %s"\n  tag          %s\n  push         %s %s and %s\n' \
    "$branch" "$base" "$old_name" "$version" "$old_code" "$new_code" "$version" "$tag" "$REMOTE" "$branch" "$tag"
  if ((dry_run)); then
    printf '\n(dry run: nothing was changed)\n'
    return 0
  fi

  printf '\nType the version (%s) to confirm, anything else cancels: ' "$version"
  local answer
  read -r answer
  [[ "$answer" == "$version" ]] || die "cancelled"

  if ((skip_check)); then
    step "CI checks skipped (--skip-check)"
  else
    step "Full check against $base (what CI runs on a push)"
    CHECK_BASE="$base" "$ROOT/scripts/check.sh" full
    step "Screenshots match their references (CI)"
    "$ROOT/dev.sh" verifyRoborazziDebug
    step "The release APK builds (the tag workflow builds it)"
    "$ROOT/dev.sh" assembleRelease
  fi

  step "Bump the version in $GRADLE_FILE"
  sed -i -e "s/^\( *versionCode = \)[0-9][0-9]*/\1$new_code/" \
    -e "s/^\( *versionName = \)\".*\"/\1\"$version\"/" "$GRADLE_FILE"
  [[ "$(current_version_name)" == "$version" && "$(current_version_code)" == "$new_code" ]] ||
    die "the version change did not apply, restore the file with: git checkout -- $GRADLE_FILE"

  step "Commit and tag"
  git add -- "$GRADLE_FILE"
  git commit -m "Release $version"
  git tag -a "$tag" -m "Skeleton $version"

  step "Push $branch and $tag to $REMOTE"
  if ! git push "$REMOTE" "$branch" "$tag"; then
    printf '\nThe commit and the tag are local. Fix the cause, then run:\n  git push %s %s %s\n' "$REMOTE" "$branch" "$tag" >&2
    exit 1
  fi
  printf '\nDone: %s pushed, the release workflow should be starting on %s.\n' "$tag" "$REMOTE"
}

# Run only when executed, not when sourced.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

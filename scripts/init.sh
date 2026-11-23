#!/usr/bin/env bash
# One-time setup of a new app from this skeleton. Renames everything, then deletes itself.
#   ./scripts/init.sh "My App" com.acme.myapp
# Changes: package and applicationId, app name, Gradle project name, Docker images/volumes/env vars,
# release secret names, artifact names, version (0.1.0 / code 1). Run it in a fresh copy, before the first commit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD_PKG="com.example.skeleton"
OLD_NAME="Skeleton"

die() { printf 'init.sh: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 2 ]] || die 'usage: ./scripts/init.sh "App Name" com.company.app'
NAME="$1"
PKG="$2"
[[ "$NAME" =~ ^[A-Za-z][A-Za-z0-9\ ]*$ ]] || die "app name must be letters, digits and spaces, starting with a letter"
[[ "$PKG" =~ ^[a-z][a-z0-9]*(\.[a-z][a-z0-9_]*)+$ ]] || die "package must look like com.company.app (lowercase)"
[[ -f "$ROOT/app/src/main/java/com/example/skeleton/MainActivity.kt" ]] || die "already initialised (skeleton package not found)"

SLUG="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed 's/--*/-/g; s/^-//; s/-$//')"
UPPER="$(printf '%s' "$SLUG" | tr '[:lower:]-' '[:upper:]_')"
CAMEL="$(printf '%s' "$NAME" | tr -d ' ')"
OLD_PATH="${OLD_PKG//./\/}"
NEW_PATH="${PKG//./\/}"
cd "$ROOT"

# 1. Move the source directories (main and test).
for set in main test; do
  base="app/src/$set/java"
  [[ -d "$base/$OLD_PATH" ]] || continue
  mkdir -p "$base/$NEW_PATH"
  cp -a "$base/$OLD_PATH/." "$base/$NEW_PATH/"
  rm -rf "$base/com/example"
  find "$base" -type d -empty -delete
  mkdir -p "$base"
done

# 2. Rewrite text files. Order matters: package first, then the more specific tokens.
mapfile -t files < <(grep -rIl -E 'skeleton|Skeleton|SKELETON' . \
  --exclude-dir=.git --exclude-dir=build --exclude-dir=.gradle --exclude-dir=.kotlin --exclude=init.sh --exclude=gradlew --exclude=gradlew.bat)
for f in "${files[@]}"; do
  sed -i \
    -e "s#com/example/skeleton#$NEW_PATH#g" \
    -e "s#com\\\\/example\\\\/skeleton#${NEW_PATH//\//\\\\/}#g" \
    -e "s#com\\.example\\.skeleton#$PKG#g" \
    -e "s#SKELETON_#${UPPER}_#g" \
    -e "s#SkeletonApplication#${CAMEL}Application#g" \
    -e "s#SkeletonTheme#${CAMEL}Theme#g" \
    -e "s#Theme\\.Skeleton#Theme.${CAMEL}#g" \
    -e "s#skeleton-#${SLUG}-#g" \
    -e "s#Skeleton#${NAME}#g" \
    "$f"
done
# 3. Version reset and the README "Using this skeleton" section.
sed -i -e 's/^\( *versionCode = \)[0-9][0-9]*/\11/' -e 's/^\( *versionName = \)".*"/\1"0.1.0"/' app/build.gradle.kts
awk '/^## Using this skeleton/{skip=1; next} /^## /{skip=0} !skip' README.md > README.md.new && mv README.md.new README.md

# 4. The Application class file follows the class name.
for f in "app/src/main/java/$NEW_PATH/SkeletonApplication.kt"; do
  [[ -f "$f" ]] && mv "$f" "app/src/main/java/$NEW_PATH/${CAMEL}Application.kt"
done

rm -- "$ROOT/scripts/init.sh"
printf 'Initialised "%s" (%s). Next: ./dev.sh recordRoborazziDebug (the app name changed the reference screenshots), git init -b develop, fill SPEC.md, ./scripts/check.sh full.\n' "$NAME" "$PKG"

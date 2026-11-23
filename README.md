# Skeleton

<One paragraph: what the app does.> Everything is built and tested in Docker, nothing else to install.
The product is described in `SPEC.md`, the quality bar in `CONSTRAINTS.md`, the plan in `tasks/`.

## Using this skeleton

This is a template for new Android apps (Kotlin, Compose, Material 3, Hilt, Roborazzi, Kover, ktlint, Docker, CI,
browser emulator, agent rules). To start a project:

1. Copy or "Use this template" on this repository, then in the new directory run
   `./scripts/init.sh "My App" com.acme.myapp`. It renames the package, application id, app name, Docker images and
   volumes, secret names and artifact names, resets the version to `0.1.0`, and deletes itself.
2. `git init -b develop` (or keep the history), enable nothing else: there are no git hooks in this skeleton. CI
   and `check.sh` scan for secrets and attribution; to scan at commit time too, add a `.githooks/pre-commit` that runs
   gitleaks and `git config core.hooksPath .githooks`.
3. Fill in `SPEC.md`, `tasks/plan.md`, `tasks/todo.md`, and the date in `CONSTRAINTS.md`.
4. Replace the example `Greeter` (domain), `MainScreen`, theme palette and launcher icon.
5. Run `./dev.sh recordRoborazziDebug` (the new name changes the reference screenshots), then `./scripts/check.sh full` to confirm a green baseline.

## Requirements

Docker (no `sudo` needed), and `/dev/kvm` only if you want the emulator. The first build downloads the Android SDK
into a Docker image and a named volume; later runs reuse them.

## Everyday commands

Run everything through `./dev.sh`; it runs Gradle in the dev container.

| Command | What it does |
|---------|--------------|
| `./dev.sh assembleDebug` | Builds the debug APK (`app/build/outputs/apk/debug/`). |
| `./dev.sh testDebugUnitTest` | Unit and Robolectric tests. |
| `./dev.sh ktlintFormat` | Formats the code (the check fails on style errors). |
| `./dev.sh recordRoborazziDebug` | Re-records the reference screenshots in `app/src/test/screenshots/`. |
| `./dev.sh verifyRoborazziDebug` | Compares the screens with those references. |
| `./dev.sh assembleRelease` | Release APK, unsigned unless the signing files exist (see Releases). |
| `./dev.sh emulator` | Pixel 8 emulator in the browser (see below). |
| `./dev.sh --shell` | A shell inside the container. |

### Checks (`CONSTRAINTS.md`)

`./scripts/check.sh <stage>` runs the quality bar, diffed against `develop` (`CHECK_BASE=<ref>` to change it):

- `fast`: floor guard, secrets scan, ktlint. Run it while editing.
- `task`: `fast` plus unit tests, Android lint and coverage rules (80 % of changed lines, 90 % of `domain/`).
  Run it before calling a task done.
- `full`: `task` plus the debug APK and a secrets scan of the whole history. This is what CI runs.

### Screenshots

Every change under `ui/` or `widget/` comes with updated screenshots (light and dark). After changing a screen run
`./dev.sh recordRoborazziDebug`, look at the PNGs in `app/src/test/screenshots/`, and commit them with the change.
CI runs `verifyRoborazziDebug` and publishes the PNGs as the `skeleton-screenshots` artifact (with `*_actual` and
`*_compare` images when something differs).

## Releases

CI (`.github/workflows/build.yml`) runs the full check on every push and pull request, verifies the screenshots and
uploads the debug APK and the screenshots.

A release is a tag:

1. Run `./scripts/release.sh 1.1.0` yourself, in a terminal (it refuses to run for an AI agent or without a terminal).
   It checks that the tree is clean and the version is new, then runs what CI will run, before changing anything:
   `./scripts/check.sh full` diffed against the remote branch, the screenshot verification and a release build. Only
   then does it set `versionName`, raise `versionCode` in `app/build.gradle.kts`, commit "Release 1.1.0", create the
   tag `v1.1.0` and push the branch and the tag. Try it first with `--dry-run`; `--skip-check` skips the CI checks.
2. The tag push starts `.github/workflows/release.yml`: it runs the full check, builds the signed APK and attaches it
   to a GitHub Release with generated notes. It refuses a tag that does not match `versionName`.

Signing uses four repository secrets (Settings > Secrets and variables > Actions); the keystore itself is never
committed:

| Secret | Content |
|--------|---------|
| `SKELETON_KEYSTORE_BASE64` | The release keystore, base64-encoded (`base64 -w0 release.keystore`). |
| `SKELETON_KEYSTORE_PASSWORD` | The keystore password. |
| `SKELETON_KEY_ALIAS` | The key alias. |
| `SKELETON_KEY_PASSWORD` | The key password. |

To create a keystore: `keytool -genkeypair -keystore release.keystore -alias release -keyalg RSA -keysize 2048
-validity 10000`. Keep a safe copy: an update must be signed with the same key as the version already installed.

To build a signed APK locally, put the keystore in the repository root and create a `signing.properties` next to it
(both are git-ignored) with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`, then run
`./dev.sh assembleRelease`; the signed file is `app/build/outputs/apk/release/app-release.apk`.

## See the app in an emulator (in your browser)

You need Docker with Compose, `/dev/kvm` (hardware virtualisation) and about 12 GB of free disk.

1. Start it from the repository root: `./dev.sh emulator`. It builds the debug APK, builds the emulator image if
   needed, then starts the container.
2. Wait for **`emulator ready: open http://localhost:6080/...`** in the terminal.
3. Open <http://localhost:6080/vnc.html?autoconnect=true&resize=scale> in your browser. You see a Pixel 8 with the
   app open. Click and type in the page as on a phone.
4. Stop it with **Ctrl+C** in the terminal.

What to expect:

- **First run:** 30 minutes or more (a ~10 GB image and the Android system image). Later runs reuse them.
- **Later runs:** about 2 minutes to "emulator ready" (the emulator itself boots in about a minute).
- **Before "emulator ready":** the page may load but show a grey screen. That is normal; reload once ready.
- **After a code change:** stop with Ctrl+C and run `./dev.sh emulator` again. It rebuilds and reinstalls the APK.
  App data is kept unless the app's signature changed, in which case it is reinstalled from scratch.
- The page is only reachable from this machine (`127.0.0.1`). Use another port with
  `SKELETON_NOVNC_PORT=6090 ./dev.sh emulator`.

### If it does not work

| Symptom | Cause and fix |
|---------|---------------|
| `emulator needs /dev/kvm` | Enable virtualisation in the BIOS, and make sure your user can use `/dev/kvm` (group `kvm`). |
| Page does not load at all | The container is not running or stopped early. Read the terminal output. Check that nothing else uses port 6080, or set `SKELETON_NOVNC_PORT`. |
| `emulator exited before booting` | Its log tail is printed just above. For a clean emulator run `docker compose --profile emulator down -v` (deletes the emulator's saved state, not your code), then `./dev.sh emulator`. |
| "System UI isn't responding" dialog | The machine is too busy for software rendering. Close heavy programs and click **Wait**, or restart. |
| Grey screen, no phone, after "ready" | Reload the browser page. |
| Docker permission errors | Your user must be allowed to run `docker` without sudo. |

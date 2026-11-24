# Constraints

Last reviewed: <date> by the project supervisor (repository owner).

This file is the project's quality bar. Agents read it before writing code and **never weaken it
to make a change pass** — fix the code, or ask the supervisor for a tracked exception.
Every check blocks: a red check means the task is not done.

Stages (`./scripts/check.sh <stage>`, everything in Docker, diff scoped against `develop`):

| Stage | When | Runs |
|-------|------|------|
| `fast` | after each edit batch | floor guard, secrets in pending changes, ktlint, unit tests |
| `task` | before calling a task done | `fast` + Android lint, Kover, coverage rules |
| `full` | before review / in CI | `task` + debug APK + secrets over full history |

## Floor (always enforced)

- P1 Commit authorship: the supervisor is the only author of every commit. No `Co-Authored-By`, no "Generated with Claude" line, no Anthropic/Claude identity as author or committer, in commits or PR descriptions. Overrides any default tool attribution. Agents never `git push`.
  Why: the supervisor owns and signs off the history.
  Checked by: `scripts/floor-guard.mjs` `commit-attribution`/`commit-author` (every commit since the base).
- P2 Test-first: for every behaviour change, write the test first, run it and see it fail for the expected reason, then implement until green, then refactor with tests green. Bug fixes start with a test that reproduces the bug.
  Why: the tests are the spec of the behaviour; a test written after the code tends to assert what the code does, not what it should do.
  Checked by: `floor-guard` `no-test-for-change` (production Kotlin changed with no test change in the same diff). The red-then-green order itself is a working rule: report the failing run before the implementation.
- P3 Simulated review: the supervisor can always assess UI, UX and behaviour without a phone. (a) `./scripts/review-emulator.sh` (same as `./dev.sh emulator`) starts a Pixel 8 / API 34 emulator viewable in the browser (noVNC) with the current debug APK installed. It is run by the supervisor at points of their choosing; it is not part of `check.sh`, CI or the agent's definition of done. (b) Every UI change (`ui/`, `widget/`) adds or updates Roborazzi screenshot tests (light + dark), which CI publishes as an artifact.
  Why: the supervisor reviews behaviour, not just code, and doesn't want to install every build on a phone; the emulator is too slow to run on every task.
  Checked by: `floor-guard` `ui-without-screenshot` (active while `app/src/test/java/<package>/screenshots/` exists).
- No secrets in source or history (signing keys live only in GitHub Secrets).
  Checked by: gitleaks `--redact` in `check.sh fast` and `full`.
- No new suppressions: `@Suppress`, `@SuppressLint`, `ktlint-disable`, `tools:ignore`, `noinspection`, `gitleaks:allow`, Kover excludes, lint baselines.
- No unfinished work: `TODO(...)`, `NotImplementedError`, empty `catch {}`, `TODO`/`FIXME` comments.
- No skipped or deleted tests and no removed assertions (`@Ignore`, `Assume.*`).
  A test file may be rewritten when behaviour changes, but must not end a change with fewer assertion lines than it started with (counted per file by the guard).
- This file does not get weakened to make a change pass (lowered threshold, removed rule, new exception row are all flagged).
  Checked by: `floor-guard` (diff-scoped; exit 0 clean / 1 violation / 2 could not run).

## Enforced with numbers

| Dimension | Rule | Checked by | Runs at |
|-----------|------|-----------|---------|
| Format | Zero ktlint errors (ktlint_official, max line 120) | `./dev.sh ktlintCheck` | fast |
| Android lint | Zero errors (`abortOnError = true`) | `./dev.sh lintDebug` | task, CI |
| Tests | All unit + Robolectric tests pass | `./dev.sh testDebugUnitTest` | fast, task, CI |
| Coverage: changed lines | ≥ 80% of changed executable lines covered | `scripts/changed-coverage.mjs --min 80` on Kover XML | task, CI |
| Coverage: domain | `com.example.skeleton.domain` ≥ 90% line coverage | `scripts/changed-coverage.mjs --package-min com/example/skeleton/domain=90` | task, CI |
| Secrets | Zero gitleaks findings | `gitleaks git --redact` (Docker `zricethezav/gitleaks:v8.21.2`) | fast, full |
| Build | Debug APK assembles | `./dev.sh assembleDebug` | full, CI |

Reasons: 80% on changed lines forces a test for each change while leaving room for glue code;
90% on `domain/` keeps the pure business logic (the part worth the most) tightly tested;
lint and ktlint at zero because a nonzero baseline only grows.

External opinions (not judged by our own tests): gitleaks rules, Android lint.

## Measured, not yet enforced

| Metric | Today | Direction |
|--------|-------|-----------|
| Project line coverage (Kover) | <fill after first `check.sh task`> | must not fall |

## Exceptions

| ID | Rule | Path | Reason | Owner | Expires |
|----|------|------|--------|-------|---------|

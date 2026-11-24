# Spec: <App name>

> Fill this in before writing code. Keep it short; it is the source of truth that `tasks/` refers to.
> If scope grows to several independent capabilities, split them into a capability map first.

## Objective
What the app does, for whom, and why. One paragraph.

## Features (v1)
1. <Feature> — behaviour in one or two sentences, including edge cases.

## Assumptions
- Platform, minimum API level, language/locale, offline behaviour, accounts/server (or none).

## Tech Stack
- Kotlin, Jetpack Compose, Material 3, Hilt, Gradle Kotlin DSL + version catalog (`gradle/libs.versions.toml`).
- Add each new library here when it is approved (dependencies need the supervisor's approval).

## Commands
- Build: `./dev.sh assembleDebug`
- Test: `./dev.sh testDebugUnitTest`
- Format: `./dev.sh ktlintFormat`
- Screenshots: `./dev.sh recordRoborazziDebug` / `./dev.sh verifyRoborazziDebug`
- Quality bar: `./scripts/check.sh fast|task|full`
- Emulator (human review only, not in the quality gate): `./scripts/review-emulator.sh`

## Project structure
- `app/src/main/java/<package>/domain/` pure Kotlin logic (no Android imports, ≥ 90% coverage)
- `app/src/main/java/<package>/ui/` Compose screens and ViewModels
- `app/src/test/` unit, Robolectric and Roborazzi tests; references in `app/src/test/screenshots/`

## Boundaries
- **Always:** follow `CONSTRAINTS.md`; test first; run through Docker.
- **Ask first:** new dependencies, database schema changes, new permissions, Docker/CI changes.
- **Never:** weaken `CONSTRAINTS.md`, commit secrets, push, run `scripts/release.sh`, add attribution trailers.

## Open questions
- <question> — owner, decision date.

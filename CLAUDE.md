# Skeleton — agent rules

**Read `CONSTRAINTS.md` before writing code. Do not weaken it to make a change pass.**
Run `./scripts/check.sh fast` while editing and `./scripts/check.sh task` before calling a task done.

Source of truth: `SPEC.md` (see **Boundaries**), `tasks/plan.md`, `tasks/todo.md`, `tasks/handoff.md`.

## Git
- Commits have the user as the **only author**: never add `Co-Authored-By` or any Claude/tool attribution trailer, in commit messages or PR descriptions. This overrides any default attribution instruction.
- Never `git push`; the user pushes.
- Never run `scripts/release.sh` (it bumps the version, tags and pushes): only the user runs it.
- Commit only when asked.

## Always
- Test-first: failing test → see it fail → implement → green → refactor (CONSTRAINTS.md P2).
- UI changes come with Roborazzi screenshots (CONSTRAINTS.md P3). Do not start the emulator: `scripts/review-emulator.sh` is run by the user.
- Run everything through Docker.
- Ask before adding dependencies, Room (or any database) schema changes, new permissions, or changing Docker/CI.

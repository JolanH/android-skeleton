# Plan: <App name> v1

Source of truth: `SPEC.md`. Vertical slices; each leaves the app buildable and tested in Docker.

## Dependency graph
```
<foundation>
    └── <domain core (pure Kotlin, TDD)>
         └── <data layer>
              └── <first usable slice>
                   └── <further slices>
```

## Build order and checkpoints
1. **<Slice>** — what it delivers. *Checkpoint: how you know it is done.*

## Risks
- <risk> — mitigation.

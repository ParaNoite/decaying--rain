# Branching Model

## Current Workstream

`mvp` is the active integration branch for the prototype skeleton and MVP gameplay implementation.

## Branch Rules

- Branch from `mvp` for all MVP feature work.
- Use `feat/mvp-<milestone>-<short-name>` for features.
- Use `fix/mvp-<short-name>` for bug fixes against MVP.
- Use `docs/mvp-<short-name>` for documentation-only changes.
- Target PRs at `mvp`, not `main`.
- Merge `mvp` into `main` only for reviewed milestone snapshots.

## Suggested Feature Branches

- `feat/mvp-m0-player-movement`
- `feat/mvp-m0-health-damage`
- `feat/mvp-m0-melee-block`
- `feat/mvp-m1-phase-loop`
- `feat/mvp-m1-base-graybox`
- `feat/mvp-m2-base-core-barriers`
- `feat/mvp-m2-firearms`
- `feat/mvp-m3-enemy-roster`
- `feat/mvp-m3-deserter-profession`
- `feat/mvp-m4-hud-feedback`

## Git Safety

Use the global `github-feature-branch-safety` skill before Git operations. Confirm every Git command with the user before running it, including read-only commands.

# Repository Instructions

This repository is a Godot 4.x project for the MVP branch of Decaying Rain.

## Branch Discipline

- Active integration branch: `mvp`.
- Feature work branches from `mvp`, not from `main`.
- Use `feat/mvp-<milestone>-<short-name>` for implementation branches.
- Pull requests for playable MVP work target `mvp`.
- `main` receives milestone-quality snapshots from `mvp` only after review.
- Before any Git operation, use the global `github-feature-branch-safety` skill and ask for explicit confirmation.

## GodotPrompter

When working on Godot-specific code, invoke the relevant GodotPrompter skill before editing:

- `godot-project-setup` for project layout, settings, autoloads, and repository hygiene.
- `scene-organization` for scene tree structure and composition boundaries.
- `event-bus` for cross-system signals.
- `resource-pattern` for typed gameplay data containers.
- `save-load` for settings, saves, and schema migration.
- `gdscript-patterns` for typed GDScript.

## Code Shape

- New runtime code goes in `scripts/` using lowercase paths.
- Existing `scripts/Player/` files are legacy prototype files until explicitly migrated.
- Scenes go in `scenes/`, with one responsibility per scene.
- Gameplay tuning data lives in `resources/` as `.tres` files backed by scripts in `scripts/resources/`.
- Use autoloads for long-lived orchestration only; keep gameplay behavior in components and systems.

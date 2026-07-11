# Decaying Rain MVP

Godot 4.x repository skeleton for a 3D rogue / wave-based survival MVP.

The current workstream is the `mvp` integration branch. New gameplay work should branch from `mvp` with `feat/mvp-*` names and target `mvp` for review.

## MVP Pillars

- Daylight scavenging: fixed terrain, randomized resources, route risk.
- Preparation: short 30-second conversion window for repair, healing, and loadout choices.
- Rain defense: wave survival around a fixed beacon base.
- Combat: melee, block, shove, stamina, and scarce firearms.
- MVP scope: 5 rain waves, 4 enemies, 4 firearms, 3 melee options, deserter profession, hunger, status interface stubs.

## Project Layout

- `assets/`: imported art, audio, materials, shaders, and UI assets.
- `resources/`: data-driven gameplay definitions and theme resources.
- `scenes/`: Godot scenes grouped by responsibility.
- `scripts/`: runtime GDScript code.
- `docs/`: architecture, MVP, and development process documentation.
- `tests/`: future automated tests.

See `docs/architecture/REPOSITORY_LAYOUT.md` for the full layout contract.

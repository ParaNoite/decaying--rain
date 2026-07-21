# Repository Layout

This repo uses a split Godot layout so content, scenes, and runtime code can evolve independently on feature branches.

## Top Level

- `assets/`: imported assets used by Godot scenes.
- `resources/`: editable game data, mostly `.tres` files using custom Resource scripts.
- `scenes/`: reusable and playable Godot scenes.
- `scripts/`: runtime GDScript, grouped by system ownership.
- `docs/`: design, architecture, and process docs.
- `tests/`: future unit and integration tests.

## Runtime Scripts

- `scripts/autoloads/`: global orchestration singletons, including the mandatory `DamageResolver` and `BuffResolver` gameplay gateways.
- `scripts/components/`: reusable node components such as health, stamina, hunger, and statuses.
- `scripts/resources/`: custom Resource classes for data-driven content.
- `scripts/systems/`: pure gameplay systems that coordinate one domain.
- `scripts/characters/`: player and enemy scene scripts.
- `scripts/base/`: beacon core, barriers, doors, and base defense code.
- `scripts/interactables/`: resource nodes, containers, and interaction points.
- `scripts/ui/`: HUD and screen controllers.
- `scripts/core/`: constants, version information, and shared low-level helpers.

## Scene Rules

- One scene has one responsibility.
- Child scenes emit signals upward.
- Parents call methods downward.
- Unrelated systems communicate through `EventBus`.
- Data definitions are Resources, not hard-coded dictionaries in scene scripts.
- Damage producers create `DamageEventData`; only `DamageResolver` may commit damage to `HealthComponent`.
- Buff callers use `BuffResolver`; `StatusContainer` stores resolved runtime state and is not a public gameplay gateway.

## UI Layers

- `scripts/ui/`: HUD, modal overlays, and screen controllers.
- The player watch UI is a modal overlay that can freeze most player actions while still showing run context such as wave countdown and map detail.

## Legacy Paths

The existing `scripts/Player/` prototype controller is legacy content. New work should use the lowercase domain folders under `scripts/`. Migrate legacy files only in a focused refactor branch.

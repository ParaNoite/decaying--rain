# System Contracts

These contracts define extension points for MVP feature branches.

## Autoloads

- `EventBus`: typed global signals for unrelated systems.
- `GameManager`: current run phase, wave index, run fail/complete transitions, default input bootstrap.
- `AudioManager`: named music and SFX entry points.
- `SaveManager`: JSON save/settings API with schema versioning.

## Run Flow

The run flow uses stable phase ids:

- `daylight`
- `preparation`
- `rain`
- `settlement`
- `complete`
- `failed`

Feature branches should emit phase changes through `GameManager.change_phase()` or consume `EventBus.phase_changed`.

## Content Data

Gameplay content should be introduced through Resource classes first:

- `RunConfig`
- `WaveDefinition`
- `EnemyDefinition`
- `WeaponDefinition`
- `ProfessionDefinition`
- `StatusEffectDefinition`
- `LootTableDefinition`
- `RandomEventDefinition`

Implementation nodes should read these definitions rather than hard-code MVP values.

## Combat

Combat payloads use `DamageEventData` so future systems can attach source tags, damage types, critical hits, stagger, and weak-point information without changing signal signatures.

## Save Data

User save data must use JSON under `user://`, not `.tres` or `.res`. Every save dictionary includes:

- `version`
- `game_version`
- `saved_at_unix`
- content payload fields

Schema migration is centralized in `SaveManager`.

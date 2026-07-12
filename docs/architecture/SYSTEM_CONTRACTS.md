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

## Player Watch UI

The player watch is a hold-to-open modal UI used during play for high-level run context.

- Input action: `watch`
- Open behavior: press and hold to enter watch view, release to exit.
- UI behavior: release mouse, show holographic watch UI, and keep only walking available while the watch is open.
- Visible data: wave countdown, map view, and detail panels.

Suggested signals:

- `watch_state_changed(active: bool)`
- `wave_timer_changed(remaining_seconds, total_seconds, wave_index)`

While watch is active, combat, interaction, sprint, slide, reload, parry, and shove are blocked by the player state layer.

## Content Data

Gameplay content should be introduced through Resource classes first:

- `RunConfig`
- `WaveDefinition`
- `EnemyDefinition`
- `WeaponDefinition`
- `ProfessionDefinition`
- `PlayerActiveSkillDefinition`
- `PerkRuleDefinition`
- `StatusEffectDefinition`
- `LootTableDefinition`
- `RandomEventDefinition`

Implementation nodes should read these definitions rather than hard-code MVP values.

`ProfessionDefinition` is the opening Perk package. All Perks share the same baseline player stats; Perk differences are expressed through advantage/disadvantage rule modifiers, status effects, action restrictions, and one active skill reference. A Perk must not define a separate hidden base stat sheet.

Each Perk has exactly one `PlayerActiveSkillDefinition` in MVP. Skill cooldowns, charges, temporary modifiers, and selected Perk state are runtime data owned by player components, not mutable Resource state.

## Combat

Combat payloads use `DamageEventData` so future systems can attach source tags, damage types, critical hits, stagger, and weak-point information without changing signal signatures.

## Save Data

User save data must use JSON under `user://`, not `.tres` or `.res`. Every save dictionary includes:

- `version`
- `game_version`
- `saved_at_unix`
- content payload fields

Schema migration is centralized in `SaveManager`.

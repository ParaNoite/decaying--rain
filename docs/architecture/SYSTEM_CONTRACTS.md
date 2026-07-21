# System Contracts

These contracts define extension points for MVP feature branches.

## Autoloads

- `EventBus`: typed global signals for unrelated systems.
- `BuffResolver`: the only gateway for status lookup, immunity, duration rules, application/removal, aggregated constraints, and periodic effects.
- `DamageResolver`: the only gateway for outgoing, critical, type, and incoming damage modifiers before health mutation.
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

Combat payloads use `DamageEventData`. Producers provide raw damage and context; they must not pre-apply outgoing or incoming multipliers.

All direct, skill, environmental, and periodic damage resolves through `DamageResolver.resolve_damage(data, target)`. Only `DamageResolver` calls `HealthComponent.take_damage()`. Damageable targets expose `get_health_component()` and may implement `try_block_damage(data)`, `get_damage_type_multiplier(type)`, and `on_damage_resolved(result)` hooks.

`DamageResolutionData` records raw and final damage, every multiplier, blocking, application, and rejection state. `EventBus.damage_resolved` is the canonical cross-system result event; `combat_hit` remains the raw request compatibility event.

Pure control events are valid when `DamageEventData.stagger > 0`, even if damage is zero. Player parry and enemy stagger therefore use the same resolver path as damaging hits.

## Buffs And Statuses

`StatusEffectDefinition` and `StatusCatalog` are read-only content data. `ActiveStatusData` is per-entity runtime state owned by `StatusContainer`.

All status application and removal resolves through `BuffResolver`. Callers must not invoke `StatusContainer.apply_resolved_status()` or `remove_resolved_status()` directly. Targets expose `get_status_container()` and may implement `is_status_immune(id)`, `get_status_duration_multiplier(id)`, and `amend_buff_constraints(constraints)`.

`StatusContainer` owns duration, stack count, refresh policy, periodic scheduling, and status snapshots. It does not mutate health, stamina, or hunger. `BuffResolver` consumes its tick signal; negative health ticks are converted into `DamageEventData` and sent through `DamageResolver`.

Player and enemy entities use the same status contract. Enemy stagger is the `staggered` status, not a separate enemy-only timer state.

## Save Data

User save data must use JSON under `user://`, not `.tres` or `.res`. Every save dictionary includes:

- `version`
- `game_version`
- `saved_at_unix`
- content payload fields

Schema migration is centralized in `SaveManager`.

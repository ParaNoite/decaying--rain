# Combat And Buff Resolution

Damage and status effects have mandatory centralized gateways in the MVP. Content scripts describe intent; resolvers own gameplay adjudication; components own entity state.

## Ownership

- `DamageEventData`: immutable-by-convention raw hit request created by weapons, skills, enemies, hazards, and periodic effects.
- `DamageResolutionData`: runtime result containing raw/final values, all multipliers, block state, and rejection reason.
- `DamageResolver`: global damage gateway and the only runtime code allowed to call `HealthComponent.take_damage()`.
- `StatusEffectDefinition`: read-only status blueprint.
- `StatusCatalog`: global lookup table for status blueprints.
- `ActiveStatusData`: per-entity mutable status instance.
- `StatusContainer`: per-entity status storage, duration/stack tracking, and tick scheduling.
- `BuffResolver`: global status gateway and the only gameplay-facing API for applying/removing statuses and resolving periodic effects.

## Damage Flow

```text
Weapon / Skill / Enemy / Hazard
    -> DamageEventData (raw values)
    -> target.receive_damage(data)
    -> DamageResolver
       -> BuffResolver outgoing constraints
       -> critical multiplier
       -> target damage-type multiplier
       -> BuffResolver incoming constraints
       -> HealthComponent.take_damage(final_amount)
       -> target.on_damage_resolved(result)
       -> EventBus.damage_resolved(result)
```

Targets expose `get_health_component()`. Optional hooks are `try_block_damage(data)`, `get_damage_type_multiplier(damage_type)`, and `on_damage_resolved(result)`.

Legacy `apply_damage(amount)` facades may remain temporarily, but they must construct `DamageEventData` and delegate to `receive_damage()`. They may never mutate health directly.

## Buff Flow

```text
Skill / Profession / Phase / Damage reaction
    -> BuffResolver.apply_status[_by_id](target, ...)
       -> status catalog lookup
       -> target immunity and duration rules
       -> StatusContainer.apply_resolved_status(...)
       -> aggregated constraints for movement/combat/damage
       -> periodic tick
          -> BuffResolver
             -> resource recovery, or
             -> DamageEventData -> DamageResolver for health loss
       -> EventBus status signals
```

Targets expose `get_status_container()`. Optional hooks are `is_status_immune(status_id)`, `get_status_duration_multiplier(status_id)`, and `amend_buff_constraints(constraints)`.

## Dependency Rules

1. Producers never pre-apply outgoing or incoming damage multipliers.
2. Only `DamageResolver` commits health damage.
3. Gameplay callers never submit directly to `StatusContainer`.
4. `StatusContainer` never changes health, stamina, or hunger.
5. Negative health ticks always become `DamageEventData`.
6. Player and enemies share the same resolver contracts.
7. EventBus publishes completed facts; it does not perform resolution.

## Autoload Order

`EventBus` loads first, followed by `BuffResolver` and `DamageResolver`. Other orchestration services load after the resolver layer.

## Required Verification

- `combat_buff_resolver_smoke.tscn`: resolver arithmetic, criticals, periodic damage, enemy status support, pure stagger, and result events.
- `player_system_smoke.tscn`: profession status duration rules and status refresh behavior.
- `enemy_system_smoke.tscn`: damage-driven death and wave cleanup.

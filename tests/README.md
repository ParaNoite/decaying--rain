# Tests

Automated tests will live here once the project adds a Godot test runner.

Recommended first coverage:

- EventBus signal contracts.
- SaveManager schema migration.
- InventoryModel item accounting.
- LootResolver deterministic drops with seeded RNG.
- PhaseController daylight / preparation / rain / settlement transitions.

## Player System Smoke Test

Run `res://tests/integration/player_system_smoke.tscn`. It instantiates the real player scene and validates profession initialization, inventory pickups, loadout switching, firearm ammunition, reloads, status refresh, and consumable use.

## Combat And Buff Resolver Smoke Test

Run `res://tests/integration/combat_buff_resolver_smoke.tscn`. It validates centralized outgoing/incoming modifiers, critical damage, periodic damage routing, enemy status support, zero-damage stagger, and the resolved damage signal.

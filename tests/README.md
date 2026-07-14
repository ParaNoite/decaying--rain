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

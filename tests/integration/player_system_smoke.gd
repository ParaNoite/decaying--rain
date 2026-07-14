extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")


func _ready() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().process_frame

	var inventory: PlayerInventoryComponent = player.inventory_component
	var loadout: PlayerLoadoutComponent = player.loadout_component
	var profession: PlayerProfessionComponent = player.profession_component
	var statuses: StatusContainer = player.status_container

	_check(inventory != null, "inventory component missing")
	_check(loadout != null, "loadout component missing")
	_check(inventory.get_quantity(&"bandage") == 1, "profession starting item missing")
	_check(loadout.equipped_weapons.size() == 3, "starting loadout should contain unarmed, crowbar and pistol")
	_check(loadout.get_current_weapon().weapon_id == &"crowbar", "crowbar should be equipped first")
	_check(statuses.has_status(&"deserter_baseline"), "profession status was not applied")
	_check(profession.get_blocked_action_ids().has(&"repair"), "perk action rule missing")

	var ammo_before_loot: int = inventory.get_quantity(&"light_ammo")
	player.receive_loot({&"light_ammo": 4})
	_check(inventory.get_quantity(&"light_ammo") == ammo_before_loot + 5, "ammo pickup multiplier was not applied")

	_check(loadout.switch_relative(1), "weapon switch failed")
	_check(loadout.get_current_weapon().weapon_id == &"pistol", "pistol was not equipped")
	var magazine_before: int = loadout.get_magazine_ammo()
	_check(loadout.consume_round(), "firearm did not consume a round")
	_check(loadout.get_magazine_ammo() == magazine_before - 1, "magazine count did not change")
	_check(loadout.finish_reload(), "reload failed")
	_check(loadout.get_magazine_ammo() == magazine_before, "reload did not refill magazine")

	_check(player.apply_status_by_id(&"rain_exposure"), "rain exposure could not be applied")
	_check(statuses.has_status(&"rain_exposure"), "rain exposure missing after apply")
	_check(is_equal_approx(statuses.get_status_remaining(&"rain_exposure"), 15.0), "perk duration modifier was not applied")
	var status_count: int = statuses.get_active_statuses().size()
	player.apply_status_by_id(&"rain_exposure")
	_check(statuses.get_active_statuses().size() == status_count, "status refresh incorrectly stacked")

	player.health.set_health(50.0)
	_check(player.use_item(&"bandage"), "bandage use failed")
	_check(is_equal_approx(player.health.current_health, 80.0), "bandage healing value is incorrect")
	_check(inventory.get_quantity(&"bandage") == 0, "bandage was not consumed")

	print("PLAYER_SYSTEM_SMOKE: PASS")
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("PLAYER_SYSTEM_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

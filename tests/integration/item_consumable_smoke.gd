extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const WORLD_PICKUP_SCENE: PackedScene = preload("res://scenes/interactables/world_pickup.tscn")


func _ready() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().process_frame

	var inventory: PlayerInventoryComponent = player.inventory_component
	_check(inventory != null, "inventory component missing")
	var bandage: ItemDefinition = inventory.get_item_definition(&"bandage")
	var medkit: ItemDefinition = inventory.get_item_definition(&"medkit")
	var food: ItemDefinition = inventory.get_item_definition(&"food_ration")
	_check(bandage != null and bandage.clears_bleeding and is_zero_approx(bandage.health_restore) and is_zero_approx(bandage.hunger_restore), "bandage effects are not bleed-only")
	_check(medkit != null and medkit.health_restore > 0.0 and is_zero_approx(medkit.hunger_restore) and not medkit.clears_bleeding, "medkit effects are not health-only")
	_check(food != null and food.hunger_restore > 0.0 and is_zero_approx(food.health_restore) and not food.clears_bleeding, "food effects are not hunger-only")

	player.health.set_health(50.0)
	_check(player.apply_status_by_id(&"bleeding"), "could not apply bleeding")
	_check(player.use_item(&"bandage"), "bandage use did not start")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.impact_start_seconds())
	_check(is_equal_approx(player.health.current_health, 50.0), "bandage restored health")
	_check(not player.status_container.has_status(&"bleeding"), "bandage did not stop bleeding")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.total_seconds())

	_check(inventory.add_item(&"medkit"), "could not add medkit")
	player.health.set_health(20.0)
	_check(player.use_item(&"medkit"), "medkit use did not start")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.impact_start_seconds())
	_check(is_equal_approx(player.health.current_health, 80.0), "medkit did not restore health")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.total_seconds())

	_check(inventory.add_item(&"food_ration"), "could not add food")
	player.health.set_health(45.0)
	player.hunger.set_hunger(40.0)
	_check(player.use_item(&"food_ration"), "food use did not start")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.impact_start_seconds())
	_check(is_equal_approx(player.health.current_health, 45.0), "food restored health")
	_check(is_equal_approx(player.hunger.current_hunger, 75.0), "food did not restore hunger")
	player.interaction_state_machine._update_instant_use(player.combat_definition.interact_timing.total_seconds())

	_check_world_model(bandage, BoxMesh, "bandage")
	_check_world_model(medkit, BoxMesh, "medkit")
	_check_world_model(food, CylinderMesh, "food")

	print("ITEM_CONSUMABLE_SMOKE: PASS")
	get_tree().quit()


func _check_world_model(item: ItemDefinition, expected_type: Variant, item_name: String) -> void:
	var pickup: WorldPickup = WORLD_PICKUP_SCENE.instantiate() as WorldPickup
	add_child(pickup)
	pickup.configure(item, 1)
	_check(is_instance_of(pickup.visual.mesh, expected_type), "%s world model has the wrong mesh" % item_name)
	pickup.queue_free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ITEM_CONSUMABLE_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

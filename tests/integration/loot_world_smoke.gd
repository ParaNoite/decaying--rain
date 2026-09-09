extends Node

const WORLD_PICKUP_SCENE: PackedScene = preload("res://scenes/interactables/world_pickup.tscn")
const WILD_LOOT_SPAWNER_SCENE: PackedScene = preload("res://scenes/systems/loot/wild_loot_spawner.tscn")


func _ready() -> void:
	_check_pickup_physics_contract()
	await _check_wild_spawn_contract()
	print("LOOT_WORLD_SMOKE: PASS")
	get_tree().quit()


func _check_pickup_physics_contract() -> void:
	var pickup: WorldPickup = WORLD_PICKUP_SCENE.instantiate() as WorldPickup
	add_child(pickup)
	_check(pickup is RigidBody3D, "world pickup must use RigidBody3D gravity")
	_check(pickup.collision_layer == 0, "world pickup must not occupy a player or enemy collision layer")
	_check(pickup.collision_mask == 1, "world pickup must only collide with the World layer")
	_check(pickup.contact_monitor and pickup.max_contacts_reported == 1, "world pickup must settle after its first World contact")
	_check(pickup.interactable.collision_layer == 8, "pickup interaction must remain on the Interactable layer")
	pickup.queue_free()


func _check_wild_spawn_contract() -> void:
	var spawner: WildLootSpawner = WILD_LOOT_SPAWNER_SCENE.instantiate() as WildLootSpawner
	spawner.minimum_spawn_count = 3
	spawner.maximum_spawn_count = 3
	add_child(spawner)
	for index: int in 4:
		var point := Marker3D.new()
		point.position = Vector3(float(index), 0.0, 0.0)
		spawner.spawn_points.add_child(point)
	await get_tree().process_frame
	var spawned_count: int = 0
	for child: Node in get_children():
		if child is WorldPickup:
			spawned_count += 1
	_check(spawned_count == 3, "wild loot spawner did not create the requested number of pickups")
	spawner.queue_free()
	for child: Node in get_children():
		if child is WorldPickup:
			child.queue_free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("LOOT_WORLD_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

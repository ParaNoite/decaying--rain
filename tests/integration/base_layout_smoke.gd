extends Node

const MVP_SCENE: PackedScene = preload("res://scenes/levels/mvp_skeleton.tscn")


func _ready() -> void:
	var level: Node3D = MVP_SCENE.instantiate() as Node3D
	_check(level != null, "mvp_skeleton must instantiate")
	level.set("auto_start_run", false)
	add_child(level)
	await get_tree().physics_frame

	var compound: Node3D = level.get_node_or_null("Base") as Node3D
	_check(compound != null, "level must instance the base compound at Base")
	_check(compound.get_node_or_null("BaseCore") != null, "Base/BaseCore path must remain stable")
	_check(compound.get_node_or_null("NorthBarrier") != null, "Base/NorthBarrier path must remain stable")
	_check(compound.get_node_or_null("NorthGate") != null, "compound must expose its north defense gate")
	_check(compound.get_node_or_null("SouthGate") != null, "compound must expose its south exploration gate")

	var required_walls: Array[String] = [
		"Perimeter/NorthWallLeft",
		"Perimeter/NorthWallRight",
		"Perimeter/SouthWallLeft",
		"Perimeter/SouthWallRight",
		"Perimeter/WestWall",
		"Perimeter/EastWall",
	]
	for wall_path: String in required_walls:
		_check_static_collision(compound, wall_path)

	_check_static_collision(compound, "Interior/WestBunker")
	_check_static_collision(compound, "Interior/EastBunker")
	_check(_count_static_colliders(compound) >= 22, "compound must provide perimeter, towers, gates, bunkers, and combat cover")

	var player: Node3D = level.get_node_or_null("Player") as Node3D
	_check(player != null, "level must contain the playable player")
	_check(absf(player.global_position.x) < 11.0 and absf(player.global_position.z) < 8.0, "player must spawn inside the compound")

	var shelter_collision: CollisionShape3D = level.get_node_or_null("BaseRainShelter/CollisionShape3D") as CollisionShape3D
	_check(shelter_collision != null and shelter_collision.shape is BoxShape3D, "base rain shelter must use a box volume")
	var shelter_shape: BoxShape3D = shelter_collision.shape as BoxShape3D
	_check(shelter_shape.size.x >= 26.0 and shelter_shape.size.z >= 20.0, "rain shelter must cover the full compound")

	var near_resource: Node3D = level.get_node_or_null("ScavengeArea/NearResource") as Node3D
	_check(near_resource != null and near_resource.global_position.z > 9.0, "scavenge resources must sit beyond the south gate")
	var spawn_points: Node3D = level.get_node_or_null("SpawnPoints") as Node3D
	_check(spawn_points != null, "level must expose enemy spawn points")
	for marker: Node in spawn_points.get_children():
		_check(marker is Marker3D and (marker as Marker3D).global_position.z < -9.0, "enemy spawn points must sit beyond the north wall")

	print("BASE_LAYOUT_SMOKE: PASS")
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()


func _check_static_collision(root: Node, path: String) -> void:
	var body: StaticBody3D = root.get_node_or_null(path) as StaticBody3D
	_check(body != null, "%s must be a StaticBody3D" % path)
	var collision: CollisionShape3D = body.get_node_or_null("Collision") as CollisionShape3D
	_check(collision != null and collision.shape != null and not collision.disabled, "%s must have enabled collision" % path)


func _count_static_colliders(node: Node) -> int:
	var count: int = 0
	if node is StaticBody3D:
		for child: Node in node.get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape != null:
				count += 1
	for child: Node in node.get_children():
		count += _count_static_colliders(child)
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("BASE_LAYOUT_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

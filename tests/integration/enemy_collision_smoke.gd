extends Node

const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")


func _ready() -> void:
	var target: Node3D = Node3D.new()
	target.position = Vector3(0.0, 0.0, -10.0)
	add_child(target)

	var left_enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	var right_enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	_check(left_enemy != null and right_enemy != null, "enemy collision test requires two EnemyBase instances")
	left_enemy.position = Vector3(-0.2, 0.0, 0.0)
	right_enemy.position = Vector3(0.2, 0.0, 0.0)
	left_enemy.target = target
	right_enemy.target = target
	left_enemy.attack_range = 0.1
	right_enemy.attack_range = 0.1
	add_child(left_enemy)
	add_child(right_enemy)

	await get_tree().physics_frame
	var collision: CollisionShape3D = left_enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
	_check(collision != null and collision.shape is CapsuleShape3D, "enemy must keep an enabled capsule collider")
	_check(left_enemy.get_collision_layer_value(3), "enemy body must exist on the enemy collision layer")
	_check(left_enemy.get_collision_mask_value(3), "enemy body must scan the enemy collision layer")

	for _frame: int in 8:
		await get_tree().physics_frame
	var separation: float = Vector2(
		left_enemy.global_position.x - right_enemy.global_position.x,
		left_enemy.global_position.z - right_enemy.global_position.z
	).length()
	_check(separation >= 0.70, "enemy capsules must separate instead of overlapping, distance=%.3f" % separation)

	print("ENEMY_COLLISION_SMOKE: PASS distance=%.3f" % separation)
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ENEMY_COLLISION_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

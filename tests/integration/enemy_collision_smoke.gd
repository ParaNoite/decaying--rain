extends Node

const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")
const RUPTURED_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/ruptured.tres")


func _ready() -> void:
	var target: Node3D = Node3D.new()
	target.position = Vector3(0.0, 0.0, -10.0)
	add_child(target)

	var left_enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	var right_enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	_check(left_enemy != null and right_enemy != null, "enemy collision test requires two EnemyBase instances")
	left_enemy.definition = RUPTURED_DEFINITION
	right_enemy.definition = RUPTURED_DEFINITION
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
	var head_zone: EnemyHitZone = left_enemy.get_node_or_null("HeadHitZone") as EnemyHitZone
	_check(head_zone != null, "enemy must expose a dedicated head hit zone")
	_check(head_zone.get_collision_layer_value(3), "enemy head hit zone must exist on the enemy hit layer")
	var head_origin: Vector3 = left_enemy.global_position + Vector3(0.0, 2.03, 3.0)
	var head_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(head_origin, head_origin + Vector3(0.0, 0.0, -6.0))
	head_query.collision_mask = 4
	head_query.collide_with_areas = true
	head_query.collide_with_bodies = true
	var head_hit: Dictionary = left_enemy.get_world_3d().direct_space_state.intersect_ray(head_query)
	_check(head_hit.get("collider") == head_zone, "head-height ray must hit the head zone before the body capsule")
	var damage_resolver: Node = get_node_or_null("/root/DamageResolver")
	_check(damage_resolver != null, "DamageResolver autoload must be available for hit-zone damage")
	var body_hit: DamageEventData = DamageEventData.new()
	body_hit.attacker_id = get_instance_id()
	body_hit.target_id = left_enemy.get_instance_id()
	body_hit.amount = 10.0
	body_hit.bypass_outgoing_modifiers = true
	body_hit.bypass_incoming_modifiers = true
	var body_resolution: DamageResolutionData = damage_resolver.call("resolve_damage", body_hit, left_enemy) as DamageResolutionData
	_check(body_resolution != null and is_equal_approx(body_resolution.final_amount, 10.0), "body hit must keep base damage")

	var headshot_hit: DamageEventData = DamageEventData.new()
	headshot_hit.attacker_id = get_instance_id()
	headshot_hit.target_id = left_enemy.get_instance_id()
	headshot_hit.amount = 10.0
	headshot_hit.source_tags = [&"headshot"]
	headshot_hit.bypass_outgoing_modifiers = true
	headshot_hit.bypass_incoming_modifiers = true
	var headshot_resolution: DamageResolutionData = damage_resolver.call("resolve_damage", headshot_hit, left_enemy) as DamageResolutionData
	_check(
		headshot_resolution != null
		and is_equal_approx(headshot_resolution.final_amount, 10.0 * left_enemy.definition.headshot_damage_multiplier),
		"headshot must resolve through DamageResolver using the enemy definition multiplier"
	)

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

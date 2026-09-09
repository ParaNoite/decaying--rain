extends Node

const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")
const RUPTURED_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/ruptured.tres")


class DamageTarget extends StaticBody3D:
	var received_hits: int = 0
	var last_damage: DamageEventData


	func _init() -> void:
		collision_layer = 2
		collision_mask = 0
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(1.0, 2.0, 1.0)
		collision.position = Vector3.UP
		collision.shape = shape
		add_child(collision)


	func receive_damage(data: DamageEventData) -> void:
		received_hits += 1
		last_damage = data


func _ready() -> void:
	var test_definition: EnemyDefinition = RUPTURED_DEFINITION.duplicate(true) as EnemyDefinition
	_check(test_definition.tracking_attack_enabled, "ruptured tracking attack must be enabled by data")
	test_definition.tracking_attack_probability = 0.0
	var enemy: EnemyBase = await _spawn_enemy(test_definition)
	_check(enemy._choose_close_attack_kind() == EnemyBase.AttackKind.NORMAL, "zero tracking probability must preserve the stationary normal attack")
	test_definition.tracking_attack_probability = 1.0
	_check(enemy._choose_close_attack_kind() == EnemyBase.AttackKind.TRACKING, "full tracking probability must select the additional tracking attack")

	var target: DamageTarget = DamageTarget.new()
	target.position = Vector3(0.0, 0.0, -2.2)
	add_child(target)
	await get_tree().physics_frame
	enemy.target = target
	enemy._begin_attack(target, EnemyBase.AttackKind.NORMAL)
	enemy._physics_process(0.10)
	_check(is_zero_approx(Vector2(enemy.velocity.x, enemy.velocity.z).length()), "stationary normal attack must remain available and keep horizontal velocity at zero")
	enemy._cancel_pending_attack()
	enemy._transition_to(EnemyBase.State.CHASE)

	enemy._begin_attack(target, EnemyBase.AttackKind.TRACKING)
	enemy._physics_process(0.10)
	var windup_speed: float = Vector2(enemy.velocity.x, enemy.velocity.z).length()
	_check(windup_speed > 0.1, "tracking attack must move through CharacterBody3D during windup")
	var animation: EnemyAnimationController = enemy.get_animation_controller()
	animation._process(0.10)
	_check(animation._walk_weight > 0.0, "moving attack must retain lower-body locomotion")

	var impact_delta: float = enemy.tracking_attack_timing.impact_start_seconds() - 0.10 + 0.001
	enemy._physics_process(impact_delta)
	animation._process(impact_delta)
	_check(is_zero_approx(Vector2(enemy.velocity.x, enemy.velocity.z).length()), "tracking attack must lock movement at impact")
	_check(target.received_hits == 1, "tracking attack must resolve exactly once at impact start")
	_check(target.last_damage != null and target.last_damage.source_tags.has(&"tracking_attack"), "tracking attack must emit its distinct damage tag")

	print("ENEMY_TRACKING_ATTACK_SMOKE: PASS")
	get_tree().quit()


func _spawn_enemy(enemy_definition: EnemyDefinition) -> EnemyBase:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.definition = enemy_definition
	add_child(enemy)
	await get_tree().physics_frame
	enemy.set_physics_process(false)
	return enemy


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ENEMY_TRACKING_ATTACK_SMOKE: %s" % message)
	get_tree().quit(1)
	assert(condition, message)

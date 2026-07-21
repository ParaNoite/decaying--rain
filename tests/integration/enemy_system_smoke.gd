extends Node

const MVP_SCENE: PackedScene = preload("res://scenes/levels/mvp_skeleton.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")
const DOORBREAKER_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/doorbreaker.tres")
const WET_GUNNER_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/wet_gunner.tres")


func _ready() -> void:
	await _check_wave_spawns_and_clears()
	await _check_doorbreaker_target_priority()
	_check_wet_gunner_definition()

	print("ENEMY_SYSTEM_SMOKE: PASS")
	get_tree().quit()


func _check_wave_spawns_and_clears() -> void:
	var level: Node3D = MVP_SCENE.instantiate() as Node3D
	add_child(level)
	await get_tree().process_frame

	var enemies: Node = level.get_node_or_null("Enemies")
	_check(enemies != null, "mvp_skeleton missing Enemies container")

	var game_manager: Node = get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager autoload missing")
	game_manager.change_phase(GameManager.PHASE_RAIN)
	await get_tree().process_frame

	_check(enemies.get_child_count() == 3, "wave 1 should spawn 3 enemies")
	for child: Node in enemies.get_children():
		_check(child is EnemyBase, "spawned child should be EnemyBase")
		var enemy: EnemyBase = child as EnemyBase
		_check(absf(enemy.global_position.y) <= 0.05, "spawned enemy root should be on the floor, got y=%.3f" % enemy.global_position.y)
		_check(enemy.global_position.z > -8.0, "spawned enemy should not start behind the north wall")
		var body_mesh: MeshInstance3D = enemy.get_node_or_null("BodyMesh") as MeshInstance3D
		_check(body_mesh != null and body_mesh.visible, "spawned enemy body mesh should be visible")
		_check(body_mesh.global_position.y > 0.5, "spawned enemy body mesh should be above the floor")
		var hit: DamageEventData = DamageEventData.new()
		hit.attacker_id = get_instance_id()
		hit.target_id = enemy.get_instance_id()
		hit.amount = 9999.0
		hit.damage_type = &"test"
		enemy.receive_damage(hit)

	await get_tree().process_frame
	await get_tree().process_frame
	_check(game_manager.current_phase == GameManager.PHASE_SETTLEMENT, "wave should advance to settlement only after enemies die")
	_check(enemies.get_child_count() == 0, "dead enemies should be cleared")

	level.queue_free()
	await get_tree().process_frame


func _check_doorbreaker_target_priority() -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	_check(enemy != null, "enemy scene must instantiate EnemyBase")
	enemy.definition = DOORBREAKER_DEFINITION
	enemy.position = Vector3.ZERO
	add_child(enemy)

	var barrier: Node3D = Node3D.new()
	barrier.name = "SmokeBarrier"
	barrier.position = Vector3(15.0, 0.0, 0.0)
	barrier.add_to_group(&"barrier")
	add_child(barrier)

	var base_core: Node3D = Node3D.new()
	base_core.name = "SmokeBaseCore"
	base_core.position = Vector3(5.0, 0.0, 0.0)
	base_core.add_to_group(&"base_core")
	add_child(base_core)

	var player: Node3D = Node3D.new()
	player.name = "SmokePlayer"
	player.position = Vector3(1.0, 0.0, 0.0)
	player.add_to_group(&"player")
	add_child(player)

	await get_tree().process_frame
	_check(enemy._find_target() == barrier, "doorbreaker should prioritize barrier before nearer base/player")

	enemy.queue_free()
	barrier.queue_free()
	base_core.queue_free()
	player.queue_free()
	await get_tree().process_frame


func _check_wet_gunner_definition() -> void:
	_check(WET_GUNNER_DEFINITION.pressure_role == EnemyDefinition.PressureRole.RANGED_PRESSURE, "wet_gunner should use ranged pressure role")
	_check(WET_GUNNER_DEFINITION.attack_range > DOORBREAKER_DEFINITION.attack_range, "wet_gunner range should exceed melee enemies")
	_check(WET_GUNNER_DEFINITION.attack_cooldown_seconds > 0.0, "wet_gunner cooldown should be data-driven")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ENEMY_SYSTEM_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

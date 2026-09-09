extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")
const ENEMY_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/ruptured.tres")
const BARRIER_SCENE: PackedScene = preload("res://scenes/base/repairable_barrier.tscn")


func _ready() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	add_child(player)
	await get_tree().process_frame
	var hud: HudController = HUD_SCENE.instantiate() as HudController
	add_child(hud)
	await get_tree().process_frame

	player.status_container.clear_resolved_statuses()
	player.apply_status_by_id(&"bleeding", 12.0)
	await get_tree().process_frame
	_check(hud.status_row.get_child_count() == 1, "bottom status row did not render one active status")
	var status_panel: PanelContainer = hud.status_row.get_child(0) as PanelContainer
	_check(status_panel != null, "bottom status row did not render a status panel")
	var status_label: Label = status_panel.get_child(0) as Label
	_check(status_label != null and status_label.text.contains("BLEEDING"), "bottom status row omitted the status name")
	_check(status_label.text.contains("12"), "bottom status row omitted the remaining duration")

	player.status_container.clear_resolved_statuses()
	await get_tree().process_frame
	_check(hud.status_row.get_child_count() == 0, "cleared statuses remained in the bottom status row")
	_check(hud.status_empty_label.visible, "bottom status row did not show its clear state")
	await _check_player_enemy_hit_feedback(player, hud)

	print("HUD_STATUS_DISPLAY_SMOKE: PASS")
	get_tree().quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("HUD_STATUS_DISPLAY_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)


func _check_player_enemy_hit_feedback(player: Player3DController, hud: HudController) -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.definition = ENEMY_DEFINITION
	enemy.position = Vector3(0.0, 0.0, -1.0)
	add_child(enemy)
	await get_tree().process_frame
	var melee_hit: DamageEventData = DamageEventData.new()
	melee_hit.attacker_id = player.get_instance_id()
	melee_hit.target_id = enemy.get_instance_id()
	melee_hit.amount = 1.0
	melee_hit.source_tags = [&"melee"]
	melee_hit.hit_position = enemy.global_position + Vector3.UP
	enemy.receive_damage(melee_hit)
	await get_tree().process_frame
	_check(hud.hit_marker.is_active(), "player melee hit did not show the center hit marker")
	_check(enemy.blood_hit_effect_count == 1, "damaging player melee hit did not create blood particles")
	_check(enemy.last_blood_hit_position == melee_hit.hit_position, "blood particles did not use the resolved hit position")
	_check(is_zero_approx(enemy.get_knockback_velocity().length()), "damaging player melee hit must not move the enemy")
	enemy.last_blood_hit_position = Vector3.ZERO
	await get_tree().physics_frame
	player.combat_driver.resolve_primary_attack(player)
	_check(enemy.last_blood_hit_position != Vector3.ZERO, "melee hit did not resolve a physics contact point")
	_check(
		not enemy.last_blood_hit_position.is_equal_approx(enemy.global_position),
		"melee hit position must be the collision contact, not the enemy origin"
	)

	hud._set_gameplay_hud_visible(false)
	_check(not hud.hit_marker.is_active(), "hidden gameplay HUD left the hit marker visible")
	hud._set_gameplay_hud_visible(true)
	var shove_enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	shove_enemy.definition = ENEMY_DEFINITION
	shove_enemy.position = Vector3(2.0, 0.0, -1.0)
	add_child(shove_enemy)
	await get_tree().process_frame
	var shove_hit: DamageEventData = DamageEventData.new()
	shove_hit.attacker_id = player.get_instance_id()
	shove_hit.target_id = shove_enemy.get_instance_id()
	shove_hit.stagger = 10.0
	shove_hit.source_tags = [&"shove"]
	shove_hit.hit_position = shove_enemy.global_position + Vector3.UP
	shove_enemy.receive_damage(shove_hit)
	await get_tree().process_frame
	_check(hud.hit_marker.is_active(), "player shove did not show the center hit marker")
	_check(shove_enemy.blood_hit_effect_count == 0, "zero-damage shove incorrectly created blood particles")
	_check(is_zero_approx(shove_enemy.get_knockback_velocity().length()), "player shove must not move the enemy")

	hud.hit_marker.hide()
	var invalid_hit: DamageEventData = DamageEventData.new()
	invalid_hit.attacker_id = player.get_instance_id()
	invalid_hit.target_id = shove_enemy.get_instance_id()
	invalid_hit.source_tags = [&"melee"]
	shove_enemy.receive_damage(invalid_hit)
	await get_tree().process_frame
	_check(not hud.hit_marker.is_active(), "invalid melee event incorrectly showed the hit marker")
	_check(shove_enemy.blood_hit_effect_count == 0, "invalid melee event incorrectly created blood particles")

	enemy.queue_free()
	shove_enemy.queue_free()
	await get_tree().process_frame
	await _check_environment_impact_feedback(player)


func _check_environment_impact_feedback(player: Player3DController) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(0.0, 1.25, -1.5)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, 0.25)
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.combat_driver.environment_impact_effect_count = 0
	player.combat_driver.resolve_primary_attack(player)
	_check(
		player.combat_driver.environment_impact_effect_count == 1,
		"nearby wall did not create a melee environment impact effect"
	)

	wall.queue_free()
	await get_tree().process_frame
	var barrier: RepairableBarrier = BARRIER_SCENE.instantiate() as RepairableBarrier
	barrier.position = Vector3(0.0, 1.1, -1.5)
	add_child(barrier)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.combat_driver.environment_impact_effect_count = 0
	player.combat_driver.resolve_primary_attack(player)
	_check(
		player.combat_driver.environment_impact_effect_count == 1,
		"repairable barrier did not create a melee environment impact effect"
	)

	barrier.queue_free()
	await get_tree().process_frame
	var ground: StaticBody3D = StaticBody3D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.position = Vector3(0.0, -0.15, -1.5)
	var ground_collision: CollisionShape3D = CollisionShape3D.new()
	var ground_shape: BoxShape3D = BoxShape3D.new()
	ground_shape.size = Vector3(4.0, 0.25, 4.0)
	ground_collision.shape = ground_shape
	ground.add_child(ground_collision)
	add_child(ground)
	var head: Node3D = player.get_node("Head") as Node3D
	head.rotation.x = deg_to_rad(-50.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.combat_driver.environment_impact_effect_count = 0
	player.combat_driver.resolve_primary_attack(player)
	_check(
		player.combat_driver.environment_impact_effect_count == 1,
		"downward melee strike did not create a ground impact effect"
	)

	ground.queue_free()
	await get_tree().process_frame

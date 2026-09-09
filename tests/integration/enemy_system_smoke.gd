extends Node

const MVP_SCENE: PackedScene = preload("res://scenes/levels/mvp_skeleton.tscn")
const MVP_RUN_CONFIG: RunConfig = preload("res://resources/gameplay/mvp_run_config.tres")
const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemies/enemy_stub.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player/player.tscn")
const RUPTURED_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/ruptured.tres")
const DOORBREAKER_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/doorbreaker.tres")
const ARMORED_SCAVENGER_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/armored_scavenger.tres")
const WET_GUNNER_DEFINITION: EnemyDefinition = preload("res://resources/gameplay/enemies/wet_gunner.tres")


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


var _spawned_event_count: int = 0
var _died_event_count: int = 0
var _combat_hit_event_count: int = 0
var _spawned_enemy_ids: Array[StringName] = []
var _died_enemy_ids: Array[StringName] = []


func _ready() -> void:
	await _check_auto_run_spawns_visible_enemies()
	await _check_rain_timeout_waits_for_clear()
	await _check_all_fixed_wave_tables_spawn()
	await _check_wave_spawns_and_clears()
	await _check_all_enemy_definitions_bind_to_visible_bodies()
	await _check_enemy_head_hit_zones()
	await _check_ruptured_heavy_attack_contract()
	await _check_ruptured_tracking_attack_contract()
	await _check_enemy_state_machine_and_melee_cooldown()
	await _check_armored_attack_direction()
	await _check_player_reactions_drive_enemy_animation()
	await _check_doorbreaker_target_priority()
	await _check_wet_gunner_hitscan_and_cooldown()

	print("ENEMY_SYSTEM_SMOKE: PASS")
	get_tree().quit()
func _check_auto_run_spawns_visible_enemies() -> void:
	var level: Node3D = MVP_SCENE.instantiate() as Node3D
	add_child(level)
	await get_tree().process_frame

	var phase_controller: PhaseController = level.get_node_or_null("PhaseController") as PhaseController
	_check(phase_controller != null, "mvp_skeleton missing PhaseController")
	_check(phase_controller.run_config == MVP_RUN_CONFIG, "auto-start should preserve the scene's exported run config")
	_check(
		is_equal_approx(phase_controller.phase_duration_seconds, MVP_RUN_CONFIG.daylight_seconds),
		"auto-start should use the configured daylight duration"
	)

	var time_until_rain: float = MVP_RUN_CONFIG.daylight_seconds + MVP_RUN_CONFIG.preparation_seconds + 0.25
	await get_tree().create_timer(time_until_rain).timeout
	_check(is_instance_valid(level), "mvp_skeleton should remain alive until the first rain phase")

	var game_manager: Node = get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager autoload missing")
	_check(game_manager.current_phase == GameManager.PHASE_RAIN, "auto-start should reach rain using configured phase durations")

	var enemies: Node = level.get_node_or_null("Enemies")
	_check(enemies != null, "mvp_skeleton missing Enemies container")
	_check(enemies.get_child_count() == 3, "auto-started wave 1 should keep 3 enemies in the runtime tree")
	for child: Node in enemies.get_children():
		_check_visible_enemy(child)

	level.queue_free()
	await get_tree().process_frame


func _check_rain_timeout_waits_for_clear() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager autoload missing")
	game_manager.change_phase(GameManager.PHASE_DAYLIGHT)

	var level: Node3D = MVP_SCENE.instantiate() as Node3D
	level.set("auto_start_run", false)
	add_child(level)
	await get_tree().process_frame

	var phase_controller: PhaseController = level.get_node_or_null("PhaseController") as PhaseController
	var enemies: Node = level.get_node_or_null("Enemies")
	_check(phase_controller != null, "mvp_skeleton missing PhaseController")
	_check(enemies != null, "mvp_skeleton missing Enemies container")
	game_manager.start_mvp_run(phase_controller.run_config)
	game_manager.change_phase(GameManager.PHASE_RAIN)
	await get_tree().process_frame
	_check(enemies.get_child_count() == 3, "rain timeout test requires an active wave")

	phase_controller.phase_time_remaining = 0.001
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game_manager.current_phase == GameManager.PHASE_RAIN, "rain timer expiry must not end an uncleared wave")
	_check(enemies.get_child_count() == 3, "rain timer expiry must not clear living enemies")

	level.queue_free()
	await get_tree().process_frame


func _check_all_fixed_wave_tables_spawn() -> void:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager autoload missing")
	game_manager.change_phase(GameManager.PHASE_DAYLIGHT)

	var level: Node3D = MVP_SCENE.instantiate() as Node3D
	level.set("auto_start_run", false)
	add_child(level)
	await get_tree().process_frame

	var wave_director: WaveDirector = level.get_node_or_null("WaveDirector") as WaveDirector
	var enemies: Node = level.get_node_or_null("Enemies")
	_check(wave_director != null, "mvp_skeleton missing WaveDirector")
	_check(enemies != null, "mvp_skeleton missing Enemies container")

	var expected_waves: Dictionary[int, Dictionary] = {
		1: {&"ruptured": 3},
		2: {&"ruptured": 4, &"doorbreaker": 1},
		3: {&"ruptured": 4, &"doorbreaker": 1, &"armored_scavenger": 1},
		4: {&"ruptured": 4, &"armored_scavenger": 2, &"wet_gunner": 1},
		5: {&"ruptured": 5, &"doorbreaker": 2, &"armored_scavenger": 2, &"wet_gunner": 2},
	}

	for wave_index: int in expected_waves.keys():
		wave_director.begin_wave(wave_index)
		await get_tree().process_frame
		var actual_counts: Dictionary[StringName, int] = {}
		var occupied_positions: Dictionary[String, bool] = {}
		for child: Node in enemies.get_children():
			_check(child is EnemyBase, "wave %d should only spawn EnemyBase nodes" % wave_index)
			var enemy: EnemyBase = _check_visible_enemy(child)
			var enemy_id: StringName = enemy.definition.enemy_id
			actual_counts[enemy_id] = actual_counts.get(enemy_id, 0) + 1
			var position_key: String = "%.2f:%.2f" % [enemy.global_position.x, enemy.global_position.z]
			_check(not occupied_positions.has(position_key), "wave %d enemies should not overlap at spawn position %s" % [wave_index, position_key])
			occupied_positions[position_key] = true
		_check(actual_counts == expected_waves[wave_index], "wave %d fixed spawn table mismatch: %s" % [wave_index, actual_counts])

	level.queue_free()
	await get_tree().process_frame


func _check_wave_spawns_and_clears() -> void:
	var level: Node3D = MVP_SCENE.instantiate() as Node3D
	add_child(level)
	await get_tree().process_frame

	var enemies: Node = level.get_node_or_null("Enemies")
	_check(enemies != null, "mvp_skeleton missing Enemies container")

	var game_manager: Node = get_node_or_null("/root/GameManager")
	_check(game_manager != null, "GameManager autoload missing")
	var event_bus: Node = get_node_or_null("/root/EventBus")
	_check(event_bus != null, "EventBus autoload missing")
	_reset_lifecycle_event_capture()
	event_bus.enemy_spawned.connect(_on_test_enemy_spawned)
	event_bus.enemy_died.connect(_on_test_enemy_died)
	event_bus.combat_hit.connect(_on_test_combat_hit)
	game_manager.change_phase(GameManager.PHASE_RAIN)
	await get_tree().process_frame

	_check(enemies.get_child_count() == 3, "wave 1 should spawn 3 enemies")
	_check(_spawned_event_count == 3, "wave 1 should emit one enemy_spawned event per enemy")
	_check(_spawned_enemy_ids.all(func(enemy_id: StringName) -> bool: return enemy_id == &"ruptured"), "wave 1 spawned events should identify ruptured enemies")
	var wave_enemies: Array[EnemyBase] = []
	for child: Node in enemies.get_children():
		wave_enemies.append(_check_visible_enemy(child))

	_deal_lethal_test_damage(wave_enemies[0])
	_deal_lethal_test_damage(wave_enemies[1])
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game_manager.current_phase == GameManager.PHASE_RAIN, "wave must remain in rain while one enemy is alive")
	_check(enemies.get_child_count() == 3, "dead enemies should remain briefly to finish death animation")
	await get_tree().create_timer(0.7).timeout
	_check(enemies.get_child_count() == 1, "partial clear should leave the surviving enemy in the tree")
	_check(_died_event_count == 2, "partial clear should emit death events only for killed enemies")

	_deal_lethal_test_damage(wave_enemies[2])

	await get_tree().process_frame
	await get_tree().process_frame
	_check(game_manager.current_phase == GameManager.PHASE_SETTLEMENT, "wave should advance to settlement only after enemies die")
	await get_tree().create_timer(0.7).timeout
	_check(enemies.get_child_count() == 0, "dead enemies should be cleared")
	_check(_combat_hit_event_count == 3, "enemy damage resolution should preserve one combat_hit event per kill")
	_check(_died_event_count == 3, "wave 1 should emit one enemy_died event per enemy")
	_check(_died_enemy_ids.all(func(enemy_id: StringName) -> bool: return enemy_id == &"ruptured"), "wave 1 death events should identify ruptured enemies")

	event_bus.enemy_spawned.disconnect(_on_test_enemy_spawned)
	event_bus.enemy_died.disconnect(_on_test_enemy_died)
	event_bus.combat_hit.disconnect(_on_test_combat_hit)

	level.queue_free()
	await get_tree().process_frame


func _check_all_enemy_definitions_bind_to_visible_bodies() -> void:
	var definitions: Array[EnemyDefinition] = [
		RUPTURED_DEFINITION,
		DOORBREAKER_DEFINITION,
		ARMORED_SCAVENGER_DEFINITION,
		WET_GUNNER_DEFINITION,
	]
	var enemy_ids: Dictionary[StringName, bool] = {}

	for definition: EnemyDefinition in definitions:
		var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
		_check(enemy != null, "enemy scene must instantiate EnemyBase")
		enemy.definition = definition
		add_child(enemy)
		await get_tree().process_frame

		_check(enemy.definition == definition, "enemy should retain definition '%s'" % definition.enemy_id)
		_check(is_equal_approx(enemy.health.max_health, definition.max_health), "'%s' health should bind from its definition" % definition.enemy_id)
		_check(is_equal_approx(enemy.fallback_move_speed, definition.move_speed), "'%s' speed should bind from its definition" % definition.enemy_id)
		_check(is_equal_approx(enemy.attack_cooldown_seconds, definition.attack_cooldown_seconds), "'%s' cooldown should bind from its definition" % definition.enemy_id)
		var visual_rig: EnemyVisualRig = enemy.get_visual_rig()
		_check(visual_rig != null, "'%s' should have a production visual rig" % definition.enemy_id)
		var body_mesh: MeshInstance3D = visual_rig.get_body_mesh()
		_check(body_mesh != null and body_mesh.visible, "'%s' should have a visible body" % definition.enemy_id)
		var material: StandardMaterial3D = body_mesh.material_override as StandardMaterial3D
		_check(material != null and material.albedo_color.is_equal_approx(definition.body_color.darkened(0.30)), "'%s' should derive its wet-cloth color from data" % definition.enemy_id)
		var animation: EnemyAnimationController = enemy.get_animation_controller()
		_check(animation != null, "'%s' should have an animation controller" % definition.enemy_id)
		_check(_count_meshes(visual_rig) >= 35, "'%s' should use a layered production mesh, not a blockout" % definition.enemy_id)
		_check(visual_rig.head != null and visual_rig.left_forearm != null, "'%s' should expose articulated upper-body pivots" % definition.enemy_id)
		_check(visual_rig.left_knee != null and visual_rig.right_knee != null, "'%s' should expose articulated leg pivots" % definition.enemy_id)
		match definition.pressure_role:
			EnemyDefinition.PressureRole.BASE_BREAKER:
				_check(visual_rig.find_child("BreakerHead", true, false) != null, "doorbreaker should carry a modeled breaching hammer")
				_check(visual_rig.find_child("WeldersFaceplate", true, false) != null, "doorbreaker should have a sealed welding-mask face")
			EnemyDefinition.PressureRole.ELITE_MELEE:
				_check(visual_rig.find_child("ScrapCleaver", true, false) != null, "armored scavenger should carry a scrap cleaver")
				_check(visual_rig.find_child("VerticalVisor", true, false) != null, "armored scavenger should have a crested plate helmet")
			EnemyDefinition.PressureRole.RANGED_PRESSURE:
				_check(visual_rig.find_child("RifleReceiver", true, false) != null, "wet gunner should carry a modeled rifle")
				_check(visual_rig.muzzle_flash != null, "wet gunner should expose a muzzle flash effect")
				_check(visual_rig.find_child("LeftGoggle", true, false) != null, "wet gunner should have a dual-goggle face")
			_:
				_check(visual_rig.find_child("RainClaw00", true, false) != null, "ruptured should carry rain claws")
				_check(visual_rig.find_child("ExposedJaw", true, false) != null, "ruptured should have an exposed asymmetrical face")
		enemy_ids[definition.enemy_id] = true

		enemy.queue_free()
		await get_tree().process_frame

	_check(enemy_ids.size() == 4, "all four enemy definitions should have unique IDs")


func _check_enemy_head_hit_zones() -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	_check(enemy != null, "enemy head hit-zone test must instantiate an enemy")
	enemy.definition = RUPTURED_DEFINITION
	add_child(enemy)
	await get_tree().physics_frame

	var head_zone: EnemyHitZone = enemy.get_node_or_null("HeadHitZone") as EnemyHitZone
	_check(head_zone != null, "enemy should expose a dedicated head hit zone")
	_check(head_zone.get_collision_layer_value(3), "enemy head hit zone should share the enemy hit collision layer")
	_check(head_zone.get_damage_tags().has(&"headshot"), "enemy head hit zone should report a headshot tag")

	var origin: Vector3 = enemy.global_position + Vector3(0.0, 2.03, 3.0)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0.0, 0.0, -6.0))
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var ray_hit: Dictionary = enemy.get_world_3d().direct_space_state.intersect_ray(query)
	_check(ray_hit.get("collider") == head_zone, "a head-height ray should hit the head zone before the body capsule")
	_check(is_equal_approx(enemy.get_hit_zone_damage_multiplier([&"headshot"]), enemy.definition.headshot_damage_multiplier), "headshot tags should use the enemy resource multiplier")
	_check(is_equal_approx(enemy.get_hit_zone_damage_multiplier([&"melee"]), 1.0), "body hits should retain normal damage")

	var damage_resolver: Node = get_node_or_null("/root/DamageResolver")
	_check(damage_resolver != null, "DamageResolver autoload missing for headshot damage test")
	var body_hit: DamageEventData = DamageEventData.new()
	body_hit.attacker_id = get_instance_id()
	body_hit.target_id = enemy.get_instance_id()
	body_hit.amount = 10.0
	body_hit.bypass_outgoing_modifiers = true
	body_hit.bypass_incoming_modifiers = true
	var body_resolution: DamageResolutionData = damage_resolver.call("resolve_damage", body_hit, enemy) as DamageResolutionData
	_check(body_resolution != null and is_equal_approx(body_resolution.final_amount, 10.0), "body hits should resolve at base damage")

	var headshot_hit: DamageEventData = DamageEventData.new()
	headshot_hit.attacker_id = get_instance_id()
	headshot_hit.target_id = enemy.get_instance_id()
	headshot_hit.amount = 10.0
	headshot_hit.source_tags = [&"headshot"]
	headshot_hit.bypass_outgoing_modifiers = true
	headshot_hit.bypass_incoming_modifiers = true
	var headshot_resolution: DamageResolutionData = damage_resolver.call("resolve_damage", headshot_hit, enemy) as DamageResolutionData
	_check(
		headshot_resolution != null
		and is_equal_approx(headshot_resolution.final_amount, 10.0 * enemy.definition.headshot_damage_multiplier),
		"headshots should resolve through DamageResolver using the enemy resource multiplier"
	)

	enemy.queue_free()
	await get_tree().process_frame


func _check_enemy_state_machine_and_melee_cooldown() -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	var heavy_test_definition: EnemyDefinition = RUPTURED_DEFINITION.duplicate(true) as EnemyDefinition
	heavy_test_definition.heavy_attack_trigger_probability = 1.0
	enemy.definition = heavy_test_definition
	enemy.position = Vector3.ZERO
	add_child(enemy)

	var target: DamageTarget = DamageTarget.new()
	target.position = Vector3(0.0, 0.0, -5.0)
	add_child(target)
	await get_tree().physics_frame
	enemy.set_physics_process(false)
	enemy.target = target
	enemy._heavy_attack_cooldown_remaining = 1.0

	enemy._physics_process(0.05)
	_check(enemy.get_state() == EnemyBase.State.CHASE, "enemy should chase a target outside attack range")
	_check(Vector2(enemy.velocity.x, enemy.velocity.z).length() > 0.0, "chasing enemy should have horizontal velocity")
	var animation: EnemyAnimationController = enemy.get_animation_controller()
	animation._process(0.12)
	_check(animation.locomotion_amount > 0.9, "chasing enemy should drive walking animation")
	var visual_rig: EnemyVisualRig = enemy.get_visual_rig()
	_check(absf(visual_rig.left_leg.rotation.x) > 0.05, "walking animation should swing the legs")
	var facing_direction: Vector3 = -enemy.global_basis.z.normalized()
	var target_direction: Vector3 = (target.global_position - enemy.global_position).normalized()
	_check(facing_direction.dot(target_direction) > 0.98, "chasing enemy should turn its visible front toward the target")

	target.position = Vector3(0.0, 0.0, -1.0)
	enemy._attack_cooldown_remaining = 0.0
	enemy._heavy_attack_cooldown_remaining = 1.0
	enemy._physics_process(0.05)
	_check(enemy.get_state() == EnemyBase.State.ATTACK, "enemy should enter attack state in range")
	_check(target.received_hits == 0, "attack windup must telegraph before dealing damage")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_ATTACK_WINDUP, "attack should start with a windup animation")
	animation._process(enemy.attack_timing.windup_seconds * 0.55)
	_check(animation.attack_pose_amount > 0.4, "attack windup should visibly raise the arms")
	_check(visual_rig.right_arm.rotation.x > 0.5, "attack telegraph should lift the right hand")
	target.position = Vector3(0.0, 0.0, -RUPTURED_DEFINITION.attack_range * 1.18)
	enemy._physics_process(enemy.attack_timing.impact_start_seconds())
	animation._process(enemy.attack_timing.impact_start_seconds() - enemy.attack_timing.windup_seconds * 0.55)
	_check(target.received_hits == 1, "melee enemy should damage only on the post-windup impact frame")
	_check(RUPTURED_DEFINITION.attack_range >= 1.7, "ruptured normal melee should use its extended reach from data")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_ATTACK_IMPACT, "attack should enter impact/recovery animation")
	animation._process(enemy.attack_timing.impact_seconds * 0.32)
	var melee_forward_dot: float = _weapon_forward_dot(enemy)
	_check(melee_forward_dot > 0.55, "melee impact should drive the weapon toward the enemy's front, dot=%.3f" % melee_forward_dot)
	_check(absf(visual_rig.left_leg.rotation.x) < 0.4, "melee impact should keep the leading foot planted instead of looking like a kick")
	enemy._physics_process(0.05)
	_check(target.received_hits == 1, "melee enemy should respect attack cooldown")
	animation._process(enemy.attack_timing.impact_seconds * 0.68 + enemy.attack_timing.recovery_seconds + 0.01)
	enemy._physics_process(enemy.attack_timing.recovery_seconds + enemy.attack_timing.impact_seconds + 0.01)
	_check(enemy.get_state() == EnemyBase.State.CHASE, "enemy should return to chase after attack recovery")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_NONE, "attack animation should return to its locomotion loop")

	var hurt: DamageEventData = DamageEventData.new()
	hurt.attacker_id = get_instance_id()
	hurt.target_id = enemy.get_instance_id()
	hurt.amount = 1.0
	hurt.damage_type = &"test"
	enemy.receive_damage(hurt)
	_check(enemy.get_state() == EnemyBase.State.HURT, "nonlethal damage should briefly interrupt the enemy")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_HURT, "normal damage should play the hurt reaction")
	_check(is_zero_approx(enemy.get_knockback_velocity().length()), "normal damage must not apply physical knockback")
	get_node("/root/BuffResolver").call("remove_status", enemy, &"staggered")
	enemy._physics_process(0.01)
	enemy._attack_cooldown_remaining = 0.0
	target.position = enemy.position + Vector3(0.0, 0.0, -1.0)
	enemy._physics_process(0.05)
	_check(enemy.get_state() == EnemyBase.State.ATTACK, "enemy should continue normal melee evaluation after being hit")
	animation._process(0.12)
	var animation_elapsed_before_repeat: float = animation._attack_total_elapsed
	animation.play_attack(enemy.attack_timing, false)
	_check(is_equal_approx(animation._attack_total_elapsed, animation_elapsed_before_repeat), "repeating an unchanged attack command should not restart its animation")

	var shove: DamageEventData = DamageEventData.new()
	shove.attacker_id = get_instance_id()
	shove.target_id = enemy.get_instance_id()
	shove.stagger = 30.0
	shove.knockback_force = 5.5
	shove.source_tags = [&"shove"]
	shove.hit_position = enemy.global_position + Vector3(0.0, 0.0, 1.0)
	enemy.receive_damage(shove)
	_check(enemy.get_state() == EnemyBase.State.HURT, "shove should interrupt an active attack")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_SHOVED, "shove should play its old knockback animation")
	var shove_velocity: float = enemy.get_knockback_velocity().length()
	_check(shove_velocity > 5.4, "shove should apply its tuned physical knockback")
	var position_before_shove: Vector3 = enemy.global_position
	enemy._physics_process(0.1)
	_check(enemy.global_position.z < position_before_shove.z, "shove should move the enemy away from the hit")
	_check(is_zero_approx(enemy._attack_elapsed), "shove should cancel the active attack timeline")

	var parry: DamageEventData = DamageEventData.new()
	parry.attacker_id = get_instance_id()
	parry.target_id = enemy.get_instance_id()
	parry.stagger = 45.0
	parry.knockback_force = 8.0
	parry.source_tags = [&"parry", &"melee"]
	parry.hit_position = enemy.global_position + Vector3(0.0, 0.0, 1.0)
	enemy.receive_damage(parry)
	_check(enemy.get_state() == EnemyBase.State.HURT, "parry should keep the enemy interrupted")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_PARRIED, "parry should play its old weapon-side knockback animation")
	_check(enemy.get_knockback_velocity().length() > shove_velocity, "parry should knock back harder than shove")

	var lethal: DamageEventData = DamageEventData.new()
	lethal.attacker_id = get_instance_id()
	lethal.target_id = enemy.get_instance_id()
	lethal.amount = 9999.0
	lethal.damage_type = &"test"
	var death_duration: float = enemy.death_timing.total_seconds()
	enemy.receive_damage(lethal)
	_check(enemy.get_state() == EnemyBase.State.DEAD, "lethal damage should enter dead state")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_DEAD, "lethal damage should play death animation before cleanup")

	target.queue_free()
	await get_tree().create_timer(death_duration + 0.1).timeout
	_check(not is_instance_valid(enemy), "enemy should be cleaned up after the death animation")


func _check_ruptured_tracking_attack_contract() -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.definition = RUPTURED_DEFINITION
	enemy.position = Vector3.ZERO
	add_child(enemy)
	var target: DamageTarget = DamageTarget.new()
	target.position = Vector3(0.0, 0.0, -2.2)
	add_child(target)
	await get_tree().physics_frame
	enemy.set_physics_process(false)
	enemy.target = target
	enemy._begin_attack(target, EnemyBase.AttackKind.TRACKING)
	enemy._physics_process(0.10)
	_check(enemy.get_state() == EnemyBase.State.ATTACK, "tracking attack should enter the attack state")
	_check(enemy.get_active_attack_kind() == EnemyBase.AttackKind.TRACKING, "tracking attack should remain distinct from the stationary normal attack")
	_check(Vector2(enemy.velocity.x, enemy.velocity.z).length() > 0.1, "tracking attack should move during its windup")
	var animation: EnemyAnimationController = enemy.get_animation_controller()
	animation._process(0.10)
	_check(animation._walk_weight > 0.0, "tracking attack should retain a low-weight lower-body locomotion blend while moving")

	var impact_delta: float = enemy.tracking_attack_timing.impact_start_seconds() - 0.10 + 0.001
	enemy._physics_process(impact_delta)
	animation._process(impact_delta)
	_check(is_zero_approx(Vector2(enemy.velocity.x, enemy.velocity.z).length()), "tracking attack should lock horizontal movement at impact")
	_check(target.received_hits == 1, "tracking attack should still resolve damage at its timing contract impact start")
	_check(target.last_damage.source_tags.has(&"tracking_attack"), "tracking attack damage should carry a distinct source tag")

	target.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _check_ruptured_heavy_attack_contract() -> void:
	_check(RUPTURED_DEFINITION.tracking_attack_enabled, "ruptured should opt into its controller-driven tracking attack through data")
	_check(RUPTURED_DEFINITION.tracking_attack_movement != null, "ruptured tracking attack should define its movement policy")
	_check(RUPTURED_DEFINITION.tracking_attack_movement.movement_source == AttackMovementDefinition.MovementSource.CONTROLLER, "tracking attack movement should be owned by the character controller")
	_check(RUPTURED_DEFINITION.tracking_attack_movement.impact_speed_multiplier <= 0.0, "tracking attack should lock its feet at the impact phase")
	_check(RUPTURED_DEFINITION.tracking_attack_movement.recovery_speed_multiplier <= 0.0, "tracking attack should remain planted during recovery")
	_check(RUPTURED_DEFINITION.heavy_attack_enabled, "ruptured should opt into its advanced heavy attack through data")
	_check(RUPTURED_DEFINITION.heavy_attack_min_range >= 2.5, "ruptured should not start a jumping heavy attack at point-blank range")
	_check(RUPTURED_DEFINITION.heavy_attack_decision_min_seconds > 0.0, "ruptured heavy attack should use a timed decision interval instead of rolling every frame")
	_check(RUPTURED_DEFINITION.heavy_attack_trigger_probability < 1.0, "ruptured heavy attack should remain a low-probability choice")
	_check(RUPTURED_DEFINITION.heavy_attack_pounce_timing.impact_start_seconds() >= 0.40, "ruptured heavy pounce should leave a readable crouched windup before contact")
	_check(RUPTURED_DEFINITION.heavy_attack_timing.impact_start_seconds() > RUPTURED_DEFINITION.heavy_attack_pounce_timing.impact_end_seconds(), "ruptured heavy slam should resolve after the pounce travel window")
	_check(RUPTURED_DEFINITION.heavy_attack_lunge_speed >= RUPTURED_DEFINITION.move_speed * 2.0, "ruptured heavy attack should abruptly burst to at least twice its walking speed")

	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.definition = RUPTURED_DEFINITION
	enemy.position = Vector3.ZERO
	add_child(enemy)
	var target: DamageTarget = DamageTarget.new()
	target.position = Vector3(0.0, 0.0, -4.5)
	add_child(target)
	await get_tree().physics_frame
	enemy.set_physics_process(false)
	enemy.target = target
	enemy._heavy_attack_decision_remaining = 0.0
	_check(enemy.heavy_attack_timing == RUPTURED_DEFINITION.heavy_attack_timing, "heavy gameplay and animation should share the definition's timing resource instance")
	_check(enemy.heavy_attack_pounce_timing == RUPTURED_DEFINITION.heavy_attack_pounce_timing, "heavy pounce contact window should use the definition timing resource instance")
	_check(enemy._can_begin_heavy_attack(4.5), "a ready heavy-attack decision should allow its configured probability roll")
	_check(enemy._heavy_attack_decision_remaining > 0.0, "a heavy-attack decision should schedule its next check interval")
	_check(not enemy._can_begin_heavy_attack(4.5), "heavy attack should not roll again before its next decision interval")
	enemy._heavy_attack_decision_remaining = 0.0

	enemy._physics_process(0.05)
	_check(enemy.get_state() == EnemyBase.State.ATTACK, "ruptured should choose heavy attack from its extended engage range")
	_check(enemy.get_active_attack_kind() == EnemyBase.AttackKind.HEAVY, "ruptured should mark the selected attack as heavy")
	var animation: EnemyAnimationController = enemy.get_animation_controller()
	var rig: EnemyVisualRig = enemy.get_visual_rig()
	var left_hand: Node3D = rig.left_forearm.find_child("LGlove", true, false) as Node3D
	var right_hand: Node3D = rig.right_forearm.find_child("RGlove", true, false) as Node3D
	var resting_hips_y: float = rig.hips.position.y
	var airborne_hips_y: float = resting_hips_y
	var early_left_hand_above_shoulder: float = -INF
	var early_right_hand_above_shoulder: float = -INF
	enemy._physics_process(0.18)
	animation._process(0.18)
	_check(target.received_hits == 0, "heavy attack should remain harmless during its crouched jump windup")
	_check(Vector2(enemy.velocity.x, enemy.velocity.z).length() <= 0.01, "heavy attack should hold position during its crouched jump windup")
	_check(rig.hips.position.y < resting_hips_y - 0.08, "heavy jump windup should visibly lower the hips into a crouch")
	_check(maxf(rig.left_knee.rotation.x, rig.right_knee.rotation.x) > 0.35, "heavy jump windup should visibly bend both knees before the leap")
	var position_before_lunge: Vector3 = enemy.global_position
	for frame: int in 3:
		var leap_delta: float = 0.16 if frame == 2 else 0.10
		enemy._physics_process(leap_delta)
		animation._process(leap_delta)
		if frame == 1:
			# The smoke scene has no floor, so keep the target inside the pounce contact range
			# while the airborne enemy still exercises its high-speed movement path.
			target.position = enemy.global_position + Vector3(0.0, 0.0, -RUPTURED_DEFINITION.heavy_attack_pounce_range + 0.2)
		if frame == 2:
			early_left_hand_above_shoulder = left_hand.global_position.y - rig.left_arm.global_position.y
			early_right_hand_above_shoulder = right_hand.global_position.y - rig.right_arm.global_position.y
			airborne_hips_y = rig.hips.position.y
	_check(target.received_hits == 0, "heavy pounce should not deal damage while its contact window is disabled")
	_check(enemy.global_position.z < position_before_lunge.z - 0.05, "heavy windup should physically lunge toward the target")
	var burst_speed: float = Vector2(enemy.velocity.x, enemy.velocity.z).length()
	_check(burst_speed >= enemy.fallback_move_speed * 2.0, "heavy windup should abruptly exceed twice the normal chase speed")
	_check(airborne_hips_y > resting_hips_y + 0.20, "heavy burst should visibly lift the body into a forward leap")
	_check(early_left_hand_above_shoulder > 0.0 and early_right_hand_above_shoulder > 0.0, "heavy leap should snap both hands above the shoulder line during the first third of windup")
	_check(left_hand.global_position.y > rig.left_arm.global_position.y and right_hand.global_position.y > rig.right_arm.global_position.y, "heavy windup should visibly hold both hands overhead")
	_check(maxf(absf(rig.left_knee.rotation.x), absf(rig.right_knee.rotation.x)) > 0.45, "heavy pounce should visibly tuck its knees during the leap")
	target.position = enemy.position + Vector3(0.0, 0.0, -RUPTURED_DEFINITION.heavy_attack_brake_distance + 0.1)
	enemy._update_attack(RUPTURED_DEFINITION.heavy_attack_brake_seconds * 0.5)
	animation._process(RUPTURED_DEFINITION.heavy_attack_brake_seconds * 0.5)
	var mid_braking_speed: float = Vector2(enemy.velocity.x, enemy.velocity.z).length()
	_check(mid_braking_speed < burst_speed and mid_braking_speed > RUPTURED_DEFINITION.heavy_attack_brake_speed * 1.5, "heavy attack should visibly decelerate instead of snapping to braking speed in one frame")
	enemy._update_attack(RUPTURED_DEFINITION.heavy_attack_brake_seconds * 0.5 + 0.01)
	animation._process(RUPTURED_DEFINITION.heavy_attack_brake_seconds * 0.5 + 0.01)
	var braking_speed: float = Vector2(enemy.velocity.x, enemy.velocity.z).length()
	_check(braking_speed <= RUPTURED_DEFINITION.heavy_attack_brake_speed + 0.01, "heavy attack should reach its configured braking speed after the short deceleration window")
	_check(burst_speed >= braking_speed * 3.0, "heavy attack braking should retain a strong final speed drop")
	_check(rig.hips.position.y <= resting_hips_y, "heavy braking should land the visual body and brace before impact")
	target.position = enemy.position + Vector3(0.0, 0.0, -RUPTURED_DEFINITION.heavy_attack_brake_distance - 0.8)
	enemy._update_attack(0.01)
	animation._process(0.01)
	_check(Vector2(enemy.velocity.x, enemy.velocity.z).length() <= RUPTURED_DEFINITION.heavy_attack_brake_speed + 0.01, "heavy braking should stay latched when the player crosses back outside the threshold")

	target.position = enemy.position + Vector3(0.0, 0.0, -RUPTURED_DEFINITION.heavy_attack_brake_distance + 0.1)
	var before_impact: float = enemy.heavy_attack_timing.impact_start_seconds() - enemy._attack_elapsed - 0.01
	enemy._update_attack(before_impact)
	animation._process(before_impact)
	_check(target.received_hits == 0, "heavy attack should remain harmless until its landing impact window")
	target.position = enemy.position + Vector3(0.0, 0.0, -1.0)
	enemy._update_attack(0.02)
	animation._process(0.02)
	_check(target.received_hits == 1, "heavy attack should resolve its only hit at the landing impact phase start")
	_check(is_equal_approx(target.last_damage.amount, RUPTURED_DEFINITION.attack_damage * RUPTURED_DEFINITION.heavy_attack_damage_multiplier), "heavy attack damage should use its resource multiplier")
	_check(target.last_damage.source_tags.has(&"heavy_attack"), "heavy attack damage should carry a distinct source tag")
	_check(rig.left_arm.rotation.z > 0.85 and rig.right_arm.rotation.z < -0.85, "heavy impact should cross both arms inward in front of the body")
	_check(rig.spine.rotation.x < -0.65, "heavy impact should fold the torso into a downward slam")
	enemy._update_attack(enemy.heavy_attack_timing.impact_seconds * 0.5)
	_check(target.received_hits == 1, "heavy attack landing damage should resolve only once")

	var interrupted: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	interrupted.definition = RUPTURED_DEFINITION
	interrupted.position = Vector3(2.0, 0.0, 0.0)
	add_child(interrupted)
	await get_tree().physics_frame
	interrupted.set_physics_process(false)
	interrupted._begin_attack(target, EnemyBase.AttackKind.HEAVY)
	var shove: DamageEventData = DamageEventData.new()
	shove.attacker_id = get_instance_id()
	shove.target_id = interrupted.get_instance_id()
	shove.stagger = 30.0
	shove.knockback_force = 5.5
	shove.source_tags = [&"shove"]
	shove.hit_position = interrupted.global_position + Vector3(0.0, 0.0, 1.0)
	interrupted.receive_damage(shove)
	_check(interrupted.get_state() == EnemyBase.State.HURT, "shove should interrupt a heavy windup")
	_check(interrupted.get_animation_controller().get_action_state() == EnemyAnimationController.ACTION_SHOVED, "shove should replace heavy windup with the old reaction animation")
	_check(is_zero_approx(interrupted._attack_elapsed), "shove should cancel the heavy attack timeline")

	enemy.queue_free()
	interrupted.queue_free()
	target.queue_free()
	await get_tree().process_frame


func _check_player_reactions_drive_enemy_animation() -> void:
	var player: Player3DController = PLAYER_SCENE.instantiate() as Player3DController
	player.position = Vector3.ZERO
	add_child(player)
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.definition = RUPTURED_DEFINITION
	enemy.position = Vector3(0.0, 0.0, -1.0)
	add_child(enemy)
	await get_tree().physics_frame
	player.set_physics_process(false)
	enemy.set_physics_process(false)

	var animation: EnemyAnimationController = enemy.get_animation_controller()
	_check(player.combat_driver.begin_shove(), "real player combat driver should begin shove")
	_check(player.combat_driver.resolve_shove(player), "real player combat driver should resolve shove")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_SHOVED, "real player shove should play the old enemy shove animation")
	var shove_velocity: float = enemy.get_knockback_velocity().length()
	_check(shove_velocity > 5.4, "real player shove should deliver physical knockback")

	var health_before_parry: float = player.health.current_health
	player.combat_state_machine.parry_active = true
	var melee_hit: DamageEventData = DamageEventData.new()
	melee_hit.attacker_id = enemy.get_instance_id()
	melee_hit.target_id = player.get_instance_id()
	melee_hit.amount = 10.0
	melee_hit.source_tags = [&"enemy", &"melee"]
	player.receive_damage(melee_hit)
	_check(is_equal_approx(player.health.current_health, health_before_parry), "successful player parry should block enemy damage")
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_PARRIED, "real player parry should play the old enemy parry animation")
	_check(enemy.get_knockback_velocity().length() > shove_velocity, "real player parry should knock back harder than shove")
	get_node("/root/BuffResolver").call("remove_status", enemy, &"staggered")
	enemy._physics_process(0.01)

	# Exercise the complete enemy attack stack and ensure its impact pose cannot
	# overwrite the synchronous parry counter-reaction.
	enemy._attack_cooldown_remaining = 0.0
	player.combat_state_machine.parry_active = true
	enemy._begin_attack(player)
	enemy._update_attack(enemy.attack_timing.impact_start_seconds() + 0.01)
	_check(enemy.get_state() == EnemyBase.State.HURT, "successful Q parry should interrupt the enemy attack")
	_check(enemy._attack_has_resolved, "a parried attack should still resolve its attack timeline once")
	animation._process(0.35)
	_check(animation.get_action_state() == EnemyAnimationController.ACTION_PARRIED, "enemy attack impact must not overwrite the Q parry animation")
	_check(absf(enemy.get_visual_rig().spine.rotation.x) > 0.25, "Q parry should hold a visible backward stagger pose")

	# The pouncing heavy attack must use the same Q window at contact, not wait
	# until its landing slam has already played.
	enemy._attack_cooldown_remaining = 0.0
	enemy._heavy_attack_cooldown_remaining = 0.0
	get_node("/root/BuffResolver").call("remove_status", enemy, &"staggered")
	enemy._physics_process(0.01)
	player.combat_state_machine.parry_active = true
	enemy._begin_attack(player, EnemyBase.AttackKind.HEAVY)
	enemy._update_attack(enemy.heavy_attack_timing.impact_start_seconds() + 0.01)
	_check(enemy.get_state() == EnemyBase.State.HURT, "Q parry should interrupt the heavy attack")
	_check(enemy._attack_has_resolved, "a parried heavy attack should still resolve its attack timeline once")

	player.queue_free()
	enemy.queue_free()
	await get_tree().process_frame


func _check_armored_attack_direction() -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	enemy.definition = ARMORED_SCAVENGER_DEFINITION
	add_child(enemy)
	await get_tree().process_frame
	enemy.set_physics_process(false)
	var animation: EnemyAnimationController = enemy.get_animation_controller()
	animation.play_attack(enemy.attack_timing, false)
	animation._process(enemy.attack_timing.impact_start_seconds() + enemy.attack_timing.impact_seconds * 0.32)
	var forward_dot: float = _weapon_forward_dot(enemy)
	_check(forward_dot > 0.55, "armored scavenger strike should drive the cleaver forward, dot=%.3f" % forward_dot)
	enemy.queue_free()
	await get_tree().process_frame


func _check_visible_enemy(child: Node) -> EnemyBase:
	_check(child is EnemyBase, "spawned child should be EnemyBase")
	var enemy: EnemyBase = child as EnemyBase
	_check(absf(enemy.global_position.y) <= 0.1, "spawned enemy root should be on the floor, got y=%.3f" % enemy.global_position.y)
	_check(enemy.global_position.z <= -64.5, "spawned enemy should remain in the north approach outside the compound")
	_check(absf(enemy.global_position.x) <= 16.25, "spawned enemy should remain inside the north approach width")
	var visual_rig: EnemyVisualRig = enemy.get_visual_rig()
	_check(visual_rig != null, "spawned enemy should have a production visual rig")
	var body_mesh: MeshInstance3D = visual_rig.get_body_mesh()
	_check(body_mesh != null and body_mesh.visible, "spawned enemy body mesh should be visible")
	_check(body_mesh.global_position.y > 0.5, "spawned enemy body mesh should be above the floor")
	return enemy


func _count_meshes(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D else 0
	for child: Node in node.get_children():
		count += _count_meshes(child)
	return count


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
	enemy.set_physics_process(false)

	barrier.queue_free()
	await get_tree().process_frame
	_check(enemy._find_target() == base_core, "doorbreaker should fall back to base_core after barriers are gone")

	base_core.queue_free()
	await get_tree().process_frame
	_check(enemy._find_target() == player, "doorbreaker should fall back to player after base targets are gone")

	enemy.queue_free()
	player.queue_free()
	await get_tree().process_frame


func _check_wet_gunner_hitscan_and_cooldown() -> void:
	_check(WET_GUNNER_DEFINITION.pressure_role == EnemyDefinition.PressureRole.RANGED_PRESSURE, "wet_gunner should use ranged pressure role")
	_check(WET_GUNNER_DEFINITION.attack_range > DOORBREAKER_DEFINITION.attack_range, "wet_gunner range should exceed melee enemies")
	_check(WET_GUNNER_DEFINITION.attack_cooldown_seconds > 0.0, "wet_gunner cooldown should be data-driven")

	var enemy: EnemyBase = ENEMY_SCENE.instantiate() as EnemyBase
	_check(enemy != null, "enemy scene must instantiate EnemyBase")
	enemy.definition = WET_GUNNER_DEFINITION
	enemy.position = Vector3.ZERO
	add_child(enemy)

	var target: DamageTarget = DamageTarget.new()
	target.position = Vector3(0.0, 0.0, -8.0)
	add_child(target)

	var blocker: StaticBody3D = _make_hitscan_blocker()
	blocker.position = Vector3(0.0, 0.0, -4.0)
	add_child(blocker)
	await get_tree().physics_frame
	enemy.set_physics_process(false)

	enemy._attack_cooldown_remaining = 0.0
	enemy._try_attack(target)
	_check(target.received_hits == 0, "wet_gunner hitscan should stop at unrelated world geometry")

	blocker.queue_free()
	await get_tree().physics_frame
	enemy._attack_cooldown_remaining = 0.0
	enemy._try_attack(target)
	_check(target.received_hits == 1, "wet_gunner hitscan should damage an unobstructed target")
	_check(target.last_damage != null and target.last_damage.damage_type == &"ballistic", "wet_gunner should emit ballistic damage")
	_check(is_equal_approx(target.last_damage.amount, WET_GUNNER_DEFINITION.attack_damage), "wet_gunner damage should come from its definition")
	var gunner_animation: EnemyAnimationController = enemy.get_animation_controller()
	gunner_animation.play_attack(enemy.attack_timing, true)
	gunner_animation._process(enemy.attack_timing.impact_start_seconds() + enemy.attack_timing.impact_seconds * 0.5)
	var gunner_forward_dot: float = _weapon_forward_dot(enemy)
	_check(gunner_forward_dot > 0.55, "wet gunner impact pose should keep the rifle pointed forward, dot=%.3f" % gunner_forward_dot)

	enemy._try_attack(target)
	_check(target.received_hits == 1, "wet_gunner should not fire again during attack cooldown")
	enemy._attack_cooldown_remaining = 0.0
	enemy._try_attack(target)
	_check(target.received_hits == 2, "wet_gunner should fire again after cooldown expires")

	enemy.queue_free()
	target.queue_free()
	await get_tree().process_frame


func _make_hitscan_blocker() -> StaticBody3D:
	var blocker: StaticBody3D = StaticBody3D.new()
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2.0, 2.5, 0.5)
	collision.position = Vector3.UP
	collision.shape = shape
	blocker.add_child(collision)
	return blocker


func _weapon_forward_dot(enemy: EnemyBase) -> float:
	var visual_rig: EnemyVisualRig = enemy.get_visual_rig()
	var weapon_forward: Vector3 = -visual_rig.weapon_mount.global_basis.y.normalized()
	var enemy_forward: Vector3 = -enemy.global_basis.z.normalized()
	return weapon_forward.dot(enemy_forward)


func _reset_lifecycle_event_capture() -> void:
	_spawned_event_count = 0
	_died_event_count = 0
	_combat_hit_event_count = 0
	_spawned_enemy_ids.clear()
	_died_enemy_ids.clear()


func _on_test_enemy_spawned(enemy_id: StringName, _instance_id: int, _wave_index: int) -> void:
	_spawned_event_count += 1
	_spawned_enemy_ids.append(enemy_id)


func _on_test_enemy_died(enemy_id: StringName, _instance_id: int, _wave_index: int) -> void:
	_died_event_count += 1
	_died_enemy_ids.append(enemy_id)


func _on_test_combat_hit(_data: DamageEventData) -> void:
	_combat_hit_event_count += 1


func _deal_lethal_test_damage(enemy: EnemyBase) -> void:
	var hit: DamageEventData = DamageEventData.new()
	hit.attacker_id = get_instance_id()
	hit.target_id = enemy.get_instance_id()
	hit.amount = 9999.0
	hit.damage_type = &"test"
	enemy.receive_damage(hit)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("ENEMY_SYSTEM_SMOKE: FAIL - %s" % message)
	get_tree().quit(1)
	assert(condition, message)

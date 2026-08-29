class_name PlayerCombatDriver
extends Node

signal light_combo_ended

@export var combat_definition: PlayerCombatDefinition
@export var stamina_path: NodePath = ^"../Components/StaminaComponent"
@export var loadout_path: NodePath = ^"../Components/PlayerLoadoutComponent"
@export var ray_origin_path: NodePath = ^"../Head/Camera3D"
@export_flags_3d_physics var firearm_collision_mask: int = 4
@export var default_weapon: WeaponDefinition

@onready var stamina: StaminaComponent = get_node(stamina_path)
@onready var loadout: PlayerLoadoutComponent = get_node_or_null(loadout_path) as PlayerLoadoutComponent
@onready var ray_origin: Node3D = get_node_or_null(ray_origin_path) as Node3D

var current_weapon: WeaponDefinition
var combo_index: int = 0
var combo_time_remaining: float = 0.0
var combo_finisher_cooldown_remaining: float = 0.0
var shove_cooldown_remaining: float = 0.0
var firearm_spread_multiplier: float = 1.0
var primary_attack_exhausted: bool = false
var heavy_attack_exhausted: bool = false

var _event_bus = null


func _ready() -> void:
	current_weapon = default_weapon
	_event_bus = get_node_or_null("/root/EventBus")
	if loadout != null:
		loadout.weapon_changed.connect(_on_weapon_changed)


func tick(delta: float) -> void:
	var combo_was_active: bool = combo_time_remaining > 0.0
	combo_time_remaining = maxf(0.0, combo_time_remaining - delta)
	combo_finisher_cooldown_remaining = maxf(0.0, combo_finisher_cooldown_remaining - delta)
	shove_cooldown_remaining = maxf(0.0, shove_cooldown_remaining - delta)
	if combo_time_remaining <= 0.0:
		if combo_was_active:
			light_combo_ended.emit()
		combo_index = 0


func begin_primary_attack() -> bool:
	if is_current_firearm():
		if loadout == null or loadout.get_magazine_ammo() <= 0:
			_emit_feedback("EMPTY - RELOAD", &"danger")
			return false
		return true

	var combat: PlayerCombatDefinition = _combat()
	if combo_finisher_cooldown_remaining > 0.0:
		return false
	var cost: float = combat.light_attack_stamina_cost
	if current_weapon != null:
		cost = current_weapon.stamina_cost
	primary_attack_exhausted = stamina != null and not stamina.consume(cost)

	combo_index = 1 if combo_time_remaining <= 0.0 else wrapi(combo_index + 1, 1, 4)
	combo_time_remaining = combat.combo_input_window
	return true


func finish_primary_attack() -> void:
	if combo_index != 3:
		return
	combo_index = 0
	combo_time_remaining = 0.0
	combo_finisher_cooldown_remaining = _combat().combo_finisher_cooldown_seconds
	light_combo_ended.emit()


func resolve_primary_attack(attacker: Node3D) -> bool:
	if is_current_firearm():
		return _resolve_firearm_attack(attacker)
	var combat: PlayerCombatDefinition = _combat()
	var damage: float = _base_damage()
	if primary_attack_exhausted:
		damage *= combat.exhausted_attack_damage_multiplier
	if combo_index == 3:
		damage *= combat.final_combo_damage_multiplier

	_emit_best_melee_hit(
		attacker,
		damage,
		combat.melee_range * combat.light_attack_reach_multiplier,
		combat.melee_radius,
		&"melee"
	)
	return true


func begin_heavy_attack() -> bool:
	if is_current_firearm():
		return false
	var combat: PlayerCombatDefinition = _combat()
	heavy_attack_exhausted = stamina != null and not stamina.consume(combat.heavy_attack_stamina_cost)
	return true


func resolve_heavy_attack(attacker: Node3D) -> bool:
	if is_current_firearm():
		return false
	var combat: PlayerCombatDefinition = _combat()
	var damage: float = _base_damage() * combat.heavy_attack_damage_multiplier
	if heavy_attack_exhausted:
		damage *= combat.exhausted_attack_damage_multiplier
	_emit_best_melee_hit(attacker, damage, combat.melee_range, combat.melee_radius, &"melee")
	return true


func try_reload() -> bool:
	return loadout != null and loadout.can_reload()


func finish_reload() -> bool:
	return loadout != null and loadout.finish_reload()


func switch_weapon(direction: int) -> bool:
	return loadout != null and loadout.switch_relative(direction)


func is_current_firearm() -> bool:
	return current_weapon != null and current_weapon.is_firearm()


func is_current_weapon_automatic() -> bool:
	return is_current_firearm() and current_weapon.automatic


func get_primary_action_duration() -> float:
	return get_primary_timing().total_seconds()


func get_reload_duration() -> float:
	return get_reload_timing().total_seconds()


func get_primary_timing(use_held_combo_timing: bool = false) -> ActionTimingDefinition:
	if current_weapon != null and current_weapon.primary_timing != null:
		if use_held_combo_timing and combo_index > 1 and current_weapon.held_combo_timing != null:
			return current_weapon.held_combo_timing
		return current_weapon.primary_timing
	return _combat().light_attack_timing


func get_heavy_timing() -> ActionTimingDefinition:
	return _combat().heavy_attack_timing


func get_reload_timing() -> ActionTimingDefinition:
	if current_weapon != null and current_weapon.is_firearm() and current_weapon.reload_timing != null:
		return current_weapon.reload_timing
	return ActionTimingDefinition.new()


func begin_shove() -> bool:
	var combat: PlayerCombatDefinition = _combat()
	if shove_cooldown_remaining > 0.0:
		return false
	if stamina != null and not stamina.consume(combat.shove_stamina_cost):
		return false

	shove_cooldown_remaining = combat.shove_cooldown
	return true


func resolve_shove(attacker: Node3D) -> bool:
	var combat: PlayerCombatDefinition = _combat()
	_emit_best_melee_hit(
		attacker,
		0.0,
		combat.shove_range,
		combat.shove_radius,
		&"shove",
		combat.shove_stagger,
		combat.shove_knockback_force
	)
	return true


func can_start_parry() -> bool:
	return current_weapon == null or current_weapon.supports_block


func _resolve_firearm_attack(attacker: Node3D) -> bool:
	if current_weapon == null or loadout == null:
		return false
	if not loadout.consume_round():
		_emit_feedback("EMPTY - RELOAD", &"danger")
		return false

	var pellet_count: int = maxi(1, current_weapon.pellet_count)
	var damage_per_pellet: float = current_weapon.base_damage / float(pellet_count)
	for pellet_index: int in pellet_count:
		_fire_ray(attacker, damage_per_pellet, pellet_index)

	if _event_bus != null:
		_event_bus.player_noise_emitted.emit(attacker.global_position, current_weapon.noise_radius, &"firearm")
	_emit_feedback("%s FIRED" % current_weapon.display_name.to_upper(), &"neutral")
	return true


func _fire_ray(attacker: Node3D, damage: float, pellet_index: int) -> void:
	if attacker == null or ray_origin == null:
		return

	var origin: Vector3 = ray_origin.global_position
	var direction: Vector3 = -ray_origin.global_transform.basis.z.normalized()
	if current_weapon.spread_degrees > 0.0:
		var seed_value: int = Time.get_ticks_usec() + pellet_index * 7919
		var random: RandomNumberGenerator = RandomNumberGenerator.new()
		random.seed = seed_value
		var spread: float = deg_to_rad(current_weapon.spread_degrees * firearm_spread_multiplier)
		direction = direction.rotated(Vector3.UP, random.randf_range(-spread, spread))
		direction = direction.rotated(ray_origin.global_transform.basis.x, random.randf_range(-spread, spread)).normalized()

	var end: Vector3 = origin + direction * current_weapon.effective_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = firearm_collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if attacker is CollisionObject3D:
		query.exclude = [(attacker as CollisionObject3D).get_rid()]

	var result: Dictionary = attacker.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result.get("collider")
	if not (collider is Node):
		return
	var receiver: Node = _find_damage_receiver(collider as Node)
	if receiver == null:
		return

	var hit_data: DamageEventData = DamageEventData.new()
	hit_data.attacker_id = attacker.get_instance_id()
	hit_data.target_id = receiver.get_instance_id()
	hit_data.amount = damage
	hit_data.damage_type = &"ballistic"
	hit_data.source_tags = [&"firearm", current_weapon.weapon_id]
	hit_data.hit_position = result.get("position", receiver.global_position if receiver is Node3D else Vector3.ZERO)
	if receiver.has_method("receive_damage"):
		receiver.call("receive_damage", hit_data)


func _find_damage_receiver(node: Node) -> Node:
	var current: Node = node
	while current != null:
		if current.has_method("receive_damage"):
			return current
		current = current.get_parent()
	return null


func _emit_best_melee_hit(
	attacker: Node3D,
	damage: float,
	reach: float,
	radius: float,
	source_tag: StringName,
	stagger: float = 0.0,
	knockback_force: float = 0.0
) -> void:
	if attacker == null:
		return

	var best_target: Node3D
	var best_distance: float = INF
	var forward: Vector3 = -attacker.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	for enemy: Node in attacker.get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D):
			continue

		var target: Node3D = enemy as Node3D
		var offset: Vector3 = target.global_position - attacker.global_position
		offset.y = 0.0
		var forward_distance: float = offset.dot(forward)
		if forward_distance < 0.0 or forward_distance > reach:
			continue

		var lateral_distance: float = (offset - forward * forward_distance).length()
		if lateral_distance > radius:
			continue
		if forward_distance < best_distance:
			best_distance = forward_distance
			best_target = target

	if best_target == null:
		return

	var hit_data: DamageEventData = DamageEventData.new()
	hit_data.attacker_id = attacker.get_instance_id()
	hit_data.target_id = best_target.get_instance_id()
	hit_data.amount = damage
	hit_data.source_tags = [source_tag]
	hit_data.stagger = stagger
	hit_data.knockback_force = knockback_force
	hit_data.hit_position = best_target.global_position

	if best_target.has_method("receive_damage"):
		best_target.receive_damage(hit_data)


func _base_damage() -> float:
	if current_weapon != null:
		return current_weapon.base_damage
	return _combat().unarmed_damage


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	if combo_time_remaining > 0.0:
		light_combo_ended.emit()
	current_weapon = weapon if weapon != null else default_weapon
	combo_index = 0
	combo_time_remaining = 0.0
	combo_finisher_cooldown_remaining = 0.0


func _emit_feedback(message: String, tone: StringName) -> void:
	if _event_bus != null:
		_event_bus.combat_feedback.emit(message, tone)


func _combat() -> PlayerCombatDefinition:
	if combat_definition != null:
		return combat_definition

	var fallback: PlayerCombatDefinition = PlayerCombatDefinition.new()
	combat_definition = fallback
	return fallback

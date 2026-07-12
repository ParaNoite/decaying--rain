class_name PlayerCombatDriver
extends Node

@export var combat_definition: PlayerCombatDefinition
@export var stamina_path: NodePath = ^"../Components/StaminaComponent"
@export var default_weapon: WeaponDefinition

@onready var stamina: StaminaComponent = get_node(stamina_path)

var current_weapon: WeaponDefinition
var combo_index: int = 0
var combo_time_remaining: float = 0.0
var shove_cooldown_remaining: float = 0.0
var outgoing_damage_multiplier: float = 1.0

var _event_bus = null


func _ready() -> void:
	current_weapon = default_weapon
	_event_bus = get_node_or_null("/root/EventBus")


func tick(delta: float) -> void:
	combo_time_remaining = maxf(0.0, combo_time_remaining - delta)
	shove_cooldown_remaining = maxf(0.0, shove_cooldown_remaining - delta)
	if combo_time_remaining <= 0.0:
		combo_index = 0


func try_light_attack(attacker: Node3D) -> bool:
	var combat: PlayerCombatDefinition = _combat()
	var cost: float = combat.light_attack_stamina_cost
	if current_weapon != null:
		cost = current_weapon.stamina_cost
	if stamina != null and not stamina.consume(cost):
		return false

	combo_index = 1 if combo_time_remaining <= 0.0 else wrapi(combo_index + 1, 1, 4)
	combo_time_remaining = combat.combo_input_window

	var damage: float = _base_damage() * outgoing_damage_multiplier
	if combo_index == 3:
		damage *= combat.final_combo_damage_multiplier

	_emit_best_melee_hit(attacker, damage, combat.melee_range, combat.melee_radius, &"melee")
	return true


func try_shove(attacker: Node3D) -> bool:
	var combat: PlayerCombatDefinition = _combat()
	if shove_cooldown_remaining > 0.0:
		return false
	if stamina != null and not stamina.consume(combat.shove_stamina_cost):
		return false

	shove_cooldown_remaining = combat.shove_cooldown
	_emit_best_melee_hit(attacker, 0.0, combat.shove_range, combat.shove_radius, &"shove", combat.shove_stagger)
	return true


func can_start_parry() -> bool:
	return true


func _emit_best_melee_hit(
	attacker: Node3D,
	damage: float,
	reach: float,
	radius: float,
	source_tag: StringName,
	stagger: float = 0.0
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
	hit_data.hit_position = best_target.global_position

	if best_target.has_method("receive_damage"):
		best_target.receive_damage(hit_data)
	elif damage > 0.0 and best_target.has_method("apply_damage"):
		best_target.apply_damage(damage)
	elif _event_bus != null:
		_event_bus.combat_hit.emit(hit_data)


func _base_damage() -> float:
	if current_weapon != null:
		return current_weapon.base_damage
	return _combat().unarmed_damage


func _combat() -> PlayerCombatDefinition:
	if combat_definition != null:
		return combat_definition

	var fallback: PlayerCombatDefinition = PlayerCombatDefinition.new()
	combat_definition = fallback
	return fallback

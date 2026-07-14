class_name PlayerCombatStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_READY: StringName = &"ready"
const STATE_LIGHT_ATTACK: StringName = &"light_attack"
const STATE_FIRE: StringName = &"fire"
const STATE_RELOAD: StringName = &"reload"
const STATE_PARRY: StringName = &"parry"
const STATE_SHOVE: StringName = &"shove"
const STATE_RECOVER: StringName = &"recover"
const STATE_DISABLED: StringName = &"disabled"

@export var combat_definition: PlayerCombatDefinition
@export var combat_driver_path: NodePath = ^"../../CombatDriver"

@onready var combat_driver: PlayerCombatDriver = get_node(combat_driver_path)

var current_state: StringName = STATE_READY
var state_time_remaining: float = 0.0
var parry_active: bool = false


func interrupt() -> void:
	parry_active = false
	state_time_remaining = 0.0
	_transition_to(STATE_READY)


func update(body: Node3D, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> void:
	combat_driver.tick(delta)
	if constraints.get("combat_blocked", false):
		_cancel_reload()
		_transition_to(STATE_DISABLED)
		_clear_actions(input_reader)
		return

	if current_state == STATE_DISABLED:
		_transition_to(STATE_READY)

	combat_driver.outgoing_damage_multiplier = float(constraints.get("outgoing_damage_multiplier", 1.0))
	combat_driver.firearm_spread_multiplier = float(constraints.get("firearm_spread_multiplier", 1.0))
	_tick_state_timer(delta)

	if current_state != STATE_READY:
		_clear_actions(input_reader)
		return

	if input_reader.consume_weapon_next():
		combat_driver.switch_weapon(1)
		return
	if input_reader.consume_weapon_previous():
		combat_driver.switch_weapon(-1)
		return

	var pressed_primary: bool = input_reader.consume_primary_attack()
	var held_primary: bool = input_reader.wants_primary_attack and (
		not combat_driver.is_current_firearm() or combat_driver.is_current_weapon_automatic()
	)
	if pressed_primary or held_primary:
		if _action_blocked(constraints, &"attack_primary"):
			_emit_blocked(&"attack_primary", &"perk_restriction")
		elif combat_driver.try_primary_attack(body):
			_transition_to(STATE_FIRE if combat_driver.is_current_firearm() else STATE_LIGHT_ATTACK)
			state_time_remaining = combat_driver.get_primary_action_duration()
			return

	if input_reader.consume_reload():
		if _action_blocked(constraints, &"reload"):
			_emit_blocked(&"reload", &"perk_restriction")
		elif combat_driver.try_reload():
			_transition_to(STATE_RELOAD)
			state_time_remaining = combat_driver.get_reload_duration()
			return

	if input_reader.consume_parry():
		if _action_blocked(constraints, &"parry"):
			_emit_blocked(&"parry", &"perk_restriction")
		elif combat_driver.can_start_parry():
			_transition_to(STATE_PARRY)
			parry_active = true
			state_time_remaining = _combat().parry_window + _combat().parry_recovery
		return

	if input_reader.consume_shove():
		if _action_blocked(constraints, &"shove"):
			_emit_blocked(&"shove", &"perk_restriction")
		elif combat_driver.try_shove(body):
			_transition_to(STATE_SHOVE)
			state_time_remaining = _combat().shove_duration
		return

	input_reader.consume_secondary_attack()


func _tick_state_timer(delta: float) -> void:
	if state_time_remaining <= 0.0:
		return

	state_time_remaining = maxf(0.0, state_time_remaining - delta)
	if current_state == STATE_PARRY and state_time_remaining <= _combat().parry_recovery:
		parry_active = false

	if state_time_remaining <= 0.0:
		if current_state == STATE_RELOAD:
			combat_driver.finish_reload()
		parry_active = false
		_transition_to(STATE_READY)


func _clear_actions(input_reader: PlayerInputReader) -> void:
	input_reader.consume_primary_attack()
	input_reader.consume_secondary_attack()
	input_reader.consume_parry()
	input_reader.consume_shove()
	input_reader.consume_reload()
	input_reader.consume_weapon_next()
	input_reader.consume_weapon_previous()


func _cancel_reload() -> void:
	if current_state == STATE_RELOAD:
		state_time_remaining = 0.0


func _action_blocked(constraints: Dictionary, action_id: StringName) -> bool:
	var blocked_actions: Array = constraints.get("blocked_action_ids", [])
	return blocked_actions.has(action_id)


func _emit_blocked(action_id: StringName, reason_id: StringName) -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.player_action_blocked.emit(action_id, reason_id)


func _transition_to(next_state: StringName) -> void:
	if current_state == next_state:
		return

	var previous_state: StringName = current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)


func _combat() -> PlayerCombatDefinition:
	if combat_definition != null:
		return combat_definition
	if combat_driver != null and combat_driver.combat_definition != null:
		return combat_driver.combat_definition

	var fallback: PlayerCombatDefinition = PlayerCombatDefinition.new()
	combat_definition = fallback
	return fallback

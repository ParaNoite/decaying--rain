class_name PlayerCombatStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_READY: StringName = &"ready"
const STATE_LIGHT_ATTACK: StringName = &"light_attack"
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


func update(body: Node3D, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> void:
	if constraints.get("combat_blocked", false):
		_transition_to(STATE_DISABLED)
		_clear_actions(input_reader)
		return

	if current_state == STATE_DISABLED:
		_transition_to(STATE_READY)

	combat_driver.outgoing_damage_multiplier = float(constraints.get("outgoing_damage_multiplier", 1.0))
	combat_driver.tick(delta)
	_tick_state_timer(delta)

	if current_state != STATE_READY:
		_clear_actions(input_reader)
		return

	if input_reader.consume_primary_attack():
		if combat_driver.try_light_attack(body):
			_transition_to(STATE_LIGHT_ATTACK)
			state_time_remaining = _combat().light_attack_windup + _combat().light_attack_recovery
		return

	if input_reader.consume_parry():
		if combat_driver.can_start_parry():
			_transition_to(STATE_PARRY)
			parry_active = true
			state_time_remaining = _combat().parry_window + _combat().parry_recovery
		return

	if input_reader.consume_shove():
		if combat_driver.try_shove(body):
			_transition_to(STATE_SHOVE)
			state_time_remaining = _combat().shove_duration
		return

	input_reader.consume_secondary_attack()
	input_reader.consume_reload()


func _tick_state_timer(delta: float) -> void:
	if state_time_remaining <= 0.0:
		return

	state_time_remaining = maxf(0.0, state_time_remaining - delta)
	if current_state == STATE_PARRY and state_time_remaining <= _combat().parry_recovery:
		parry_active = false

	if state_time_remaining <= 0.0:
		parry_active = false
		_transition_to(STATE_READY)


func _clear_actions(input_reader: PlayerInputReader) -> void:
	input_reader.consume_primary_attack()
	input_reader.consume_secondary_attack()
	input_reader.consume_parry()
	input_reader.consume_shove()
	input_reader.consume_reload()


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

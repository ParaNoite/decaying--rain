class_name PlayerCombatStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)
signal action_phase_changed(state: StringName, phase: ActionTimingDefinition.Phase)

const STATE_READY: StringName = &"ready"
const STATE_LIGHT_ATTACK: StringName = &"light_attack"
const STATE_HEAVY_ATTACK: StringName = &"heavy_attack"
const STATE_FIRE: StringName = &"fire"
const STATE_RELOAD: StringName = &"reload"
const STATE_PARRY: StringName = &"parry"
const STATE_SHOVE: StringName = &"shove"
const STATE_DISABLED: StringName = &"disabled"

@export var combat_definition: PlayerCombatDefinition
@export var combat_driver_path: NodePath = ^"../../CombatDriver"

@onready var combat_driver: PlayerCombatDriver = get_node(combat_driver_path)

var current_state: StringName = STATE_READY
var state_time_remaining: float = 0.0
var state_elapsed: float = 0.0
var parry_active: bool = false
var current_action_timing: ActionTimingDefinition

var _action_resolved: bool = false


func interrupt() -> void:
	_clear_current_action()
	_transition_to(STATE_READY)


func update(body: Node3D, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> void:
	combat_driver.tick(delta)
	if constraints.get("combat_blocked", false):
		_clear_current_action()
		_transition_to(STATE_DISABLED)
		_clear_actions(input_reader)
		return

	if current_state == STATE_DISABLED:
		_transition_to(STATE_READY)

	combat_driver.firearm_spread_multiplier = float(constraints.get("firearm_spread_multiplier", 1.0))
	_tick_action(body, delta)

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
		elif combat_driver.begin_primary_attack():
			_start_action(
				body,
				STATE_FIRE if combat_driver.is_current_firearm() else STATE_LIGHT_ATTACK,
				combat_driver.get_primary_timing(held_primary)
			)
			return

	if input_reader.consume_secondary_attack():
		if _action_blocked(constraints, &"attack_secondary"):
			_emit_blocked(&"attack_secondary", &"perk_restriction")
		elif combat_driver.begin_heavy_attack():
			_start_action(body, STATE_HEAVY_ATTACK, combat_driver.get_heavy_timing())
			return

	if input_reader.consume_reload():
		if _action_blocked(constraints, &"reload"):
			_emit_blocked(&"reload", &"perk_restriction")
		elif combat_driver.try_reload():
			_start_action(body, STATE_RELOAD, combat_driver.get_reload_timing())
			return

	if input_reader.consume_parry():
		if _action_blocked(constraints, &"parry"):
			_emit_blocked(&"parry", &"perk_restriction")
		elif combat_driver.can_start_parry():
			_start_action(body, STATE_PARRY, _combat().parry_timing)
			return

	if input_reader.consume_shove():
		if _action_blocked(constraints, &"shove"):
			_emit_blocked(&"shove", &"perk_restriction")
		elif combat_driver.begin_shove():
			_start_action(body, STATE_SHOVE, _combat().shove_timing)
			return

func get_current_action_timing() -> ActionTimingDefinition:
	return current_action_timing


func get_current_action_phase() -> ActionTimingDefinition.Phase:
	if current_action_timing == null:
		return ActionTimingDefinition.Phase.COMPLETE
	return current_action_timing.phase_at(state_elapsed)


func _start_action(body: Node3D, next_state: StringName, timing: ActionTimingDefinition) -> void:
	current_action_timing = timing if timing != null else ActionTimingDefinition.new()
	state_elapsed = 0.0
	state_time_remaining = current_action_timing.total_seconds()
	_action_resolved = false
	_transition_to(next_state)
	_update_parry_active()
	action_phase_changed.emit(current_state, get_current_action_phase())
	_resolve_if_due(body)
	if state_time_remaining <= 0.0:
		_finish_action()


func _tick_action(body: Node3D, delta: float) -> void:
	if current_state in [STATE_READY, STATE_DISABLED] or current_action_timing == null:
		return

	var previous_phase := get_current_action_phase()
	state_elapsed = minf(current_action_timing.total_seconds(), state_elapsed + maxf(0.0, delta))
	state_time_remaining = maxf(0.0, current_action_timing.total_seconds() - state_elapsed)
	_resolve_if_due(body)
	_update_parry_active()
	var next_phase := get_current_action_phase()
	if next_phase != previous_phase:
		action_phase_changed.emit(current_state, next_phase)
	if state_time_remaining <= 0.0:
		_finish_action()


func _resolve_if_due(body: Node3D) -> void:
	if _action_resolved or current_action_timing == null:
		return
	if state_elapsed < current_action_timing.impact_start_seconds():
		return
	_action_resolved = true
	match current_state:
		STATE_LIGHT_ATTACK, STATE_FIRE:
			combat_driver.resolve_primary_attack(body)
		STATE_HEAVY_ATTACK:
			combat_driver.resolve_heavy_attack(body)
		STATE_RELOAD:
			combat_driver.finish_reload()
		STATE_SHOVE:
			combat_driver.resolve_shove(body)


func _update_parry_active() -> void:
	if current_state != STATE_PARRY or current_action_timing == null:
		parry_active = false
		return
	parry_active = (
		state_elapsed >= current_action_timing.release_start_seconds()
		and state_elapsed < current_action_timing.impact_end_seconds()
	)


func _finish_action() -> void:
	if current_state == STATE_LIGHT_ATTACK:
		combat_driver.finish_primary_attack()
	_clear_current_action()
	_transition_to(STATE_READY)


func _clear_current_action() -> void:
	parry_active = false
	state_elapsed = 0.0
	state_time_remaining = 0.0
	current_action_timing = null
	_action_resolved = false


func _clear_actions(input_reader: PlayerInputReader) -> void:
	input_reader.consume_primary_attack()
	input_reader.consume_secondary_attack()
	input_reader.consume_parry()
	input_reader.consume_shove()
	input_reader.consume_reload()
	input_reader.consume_weapon_next()
	input_reader.consume_weapon_previous()


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

	var fallback := PlayerCombatDefinition.new()
	combat_definition = fallback
	return fallback

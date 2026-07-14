class_name PlayerInteractionStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_NONE: StringName = &"none"
const STATE_FOCUS: StringName = &"focus"
const STATE_INSTANT_USE: StringName = &"instant_use"
const STATE_HOLD_USE: StringName = &"hold_use"
const STATE_LOOTING: StringName = &"looting"
const STATE_HARVESTING: StringName = &"harvesting"
const STATE_REPAIRING: StringName = &"repairing"
const STATE_DISABLED: StringName = &"disabled"

@export var interaction_driver_path: NodePath = ^"../../InteractionDriver"

@onready var interaction_driver: PlayerInteractionDriver = get_node(interaction_driver_path)

var current_state: StringName = STATE_NONE
var _use_flash_time: float = 0.0
var _hold_elapsed: float = 0.0


func update(actor: Node, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> void:
	if constraints.get("interaction_blocked", false):
		input_reader.consume_interact()
		interaction_driver.clear_prompt()
		_transition_to(STATE_DISABLED)
		return

	if current_state == STATE_DISABLED:
		_transition_to(STATE_NONE)

	interaction_driver.refresh_focus()
	if _is_holding():
		_update_hold(actor, input_reader, delta)
		return

	if _use_flash_time > 0.0:
		_use_flash_time = maxf(0.0, _use_flash_time - delta)

	if input_reader.consume_interact():
		var action_id: StringName = interaction_driver.get_focus_action_id()
		if _action_blocked(constraints, action_id):
			_emit_blocked(action_id, &"perk_restriction")
			return
		if interaction_driver.get_focus_hold_duration() > 0.0:
			_hold_elapsed = 0.0
			_transition_to(_hold_state_for_action(action_id))
		else:
			interaction_driver.interact(actor)
			_use_flash_time = 0.12
			_transition_to(STATE_INSTANT_USE)
		return

	if _use_flash_time > 0.0:
		return

	if interaction_driver.focused_interactable != null:
		_transition_to(STATE_FOCUS)
	else:
		_transition_to(STATE_NONE)


func _update_hold(actor: Node, input_reader: PlayerInputReader, delta: float) -> void:
	if interaction_driver.focused_interactable == null or not input_reader.wants_interact:
		_hold_elapsed = 0.0
		interaction_driver.restore_prompt()
		_transition_to(STATE_FOCUS if interaction_driver.focused_interactable != null else STATE_NONE)
		return

	_hold_elapsed += delta
	interaction_driver.update_hold_prompt(_hold_elapsed)
	if _hold_elapsed < interaction_driver.get_focus_hold_duration():
		return
	interaction_driver.interact(actor)
	_hold_elapsed = 0.0
	_use_flash_time = 0.12
	_transition_to(STATE_INSTANT_USE)


func _is_holding() -> bool:
	return current_state in [STATE_HOLD_USE, STATE_LOOTING, STATE_HARVESTING, STATE_REPAIRING]


func _hold_state_for_action(action_id: StringName) -> StringName:
	match action_id:
		&"loot":
			return STATE_LOOTING
		&"harvest":
			return STATE_HARVESTING
		&"repair":
			return STATE_REPAIRING
		_:
			return STATE_HOLD_USE


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

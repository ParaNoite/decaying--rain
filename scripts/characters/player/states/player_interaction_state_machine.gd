class_name PlayerInteractionStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_NONE: StringName = &"none"
const STATE_FOCUS: StringName = &"focus"
const STATE_INSTANT_USE: StringName = &"instant_use"
const STATE_ITEM_USE: StringName = &"item_use"
const STATE_HOLD_USE: StringName = &"hold_use"
const STATE_LOOTING: StringName = &"looting"
const STATE_HARVESTING: StringName = &"harvesting"
const STATE_REPAIRING: StringName = &"repairing"
const STATE_DISABLED: StringName = &"disabled"

@export var interaction_driver_path: NodePath = ^"../../InteractionDriver"
@export var combat_definition: PlayerCombatDefinition

@onready var interaction_driver: PlayerInteractionDriver = get_node(interaction_driver_path)

var current_state: StringName = STATE_NONE
var _action_elapsed: float = 0.0
var _action_resolved: bool = false
var _pending_actor: Node
var _pending_target: InteractableComponent
var _pending_item_id: StringName = &""
var _hold_elapsed: float = 0.0


func update(actor: Node, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> void:
	if constraints.get("interaction_blocked", false) and not _is_item_use_pending():
		input_reader.consume_interact()
		interaction_driver.clear_prompt()
		_cancel_pending_use()
		_transition_to(STATE_DISABLED)
		return

	if current_state == STATE_DISABLED:
		_transition_to(STATE_NONE)

	interaction_driver.refresh_focus()
	if current_state == STATE_INSTANT_USE:
		_update_instant_use(delta)
		return
	if _is_holding():
		_update_hold(actor, input_reader, delta)
		return

	if input_reader.consume_interact():
		var action_id: StringName = interaction_driver.get_focus_action_id()
		if _action_blocked(constraints, action_id):
			_emit_blocked(action_id, &"perk_restriction")
			return
		if interaction_driver.get_focus_hold_duration() > 0.0:
			_hold_elapsed = 0.0
			_transition_to(_hold_state_for_action(action_id))
		else:
			_begin_instant_use(actor)
		return

	if interaction_driver.has_valid_focus():
		_transition_to(STATE_FOCUS)
	else:
		_transition_to(STATE_NONE)


func _update_hold(actor: Node, input_reader: PlayerInputReader, delta: float) -> void:
	if not interaction_driver.has_valid_focus() or not input_reader.wants_interact:
		_hold_elapsed = 0.0
		interaction_driver.restore_prompt()
		_transition_to(STATE_FOCUS if interaction_driver.has_valid_focus() else STATE_NONE)
		return

	_hold_elapsed += delta
	interaction_driver.update_hold_prompt(_hold_elapsed)
	if _hold_elapsed < interaction_driver.get_focus_hold_duration():
		return
	_hold_elapsed = 0.0
	_begin_instant_use(actor)


func _begin_instant_use(actor: Node) -> void:
	if not interaction_driver.has_valid_focus():
		_transition_to(STATE_NONE)
		return
	_pending_actor = actor
	_pending_target = interaction_driver.focused_interactable
	_action_elapsed = 0.0
	_action_resolved = false
	_transition_to(STATE_INSTANT_USE)
	_resolve_instant_use_if_due()


func request_item_use(actor: Node, item_id: StringName, constraints: Dictionary) -> bool:
	if actor == null or item_id == &"" or current_state == STATE_INSTANT_USE or _is_holding():
		return false
	if _action_blocked(constraints, &"use_item"):
		_emit_blocked(&"use_item", &"perk_restriction")
		return false
	_pending_actor = actor
	_pending_target = null
	_pending_item_id = item_id
	_action_elapsed = 0.0
	_action_resolved = false
	_transition_to(STATE_INSTANT_USE)
	_resolve_instant_use_if_due()
	return true


func update_held_item_use(
	actor: Node,
	item_id: StringName,
	input_reader: PlayerInputReader,
	constraints: Dictionary,
	delta: float
) -> bool:
	if current_state == STATE_ITEM_USE:
		if constraints.get("interaction_blocked", false):
			cancel_held_item_use()
			return false
		_update_held_item_use(input_reader, delta)
		return true
	if actor == null or item_id == &"" or not input_reader.wants_primary_attack:
		return false
	if constraints.get("interaction_blocked", false) or _action_blocked(constraints, &"use_item"):
		_emit_blocked(&"use_item", &"perk_restriction")
		return false
	if current_state == STATE_INSTANT_USE or _is_holding():
		return false
	_pending_actor = actor
	_pending_target = null
	_pending_item_id = item_id
	_action_elapsed = 0.0
	_action_resolved = false
	_transition_to(STATE_ITEM_USE)
	_emit_item_use_progress(true)
	_update_held_item_use(input_reader, delta)
	return true


func cancel_held_item_use() -> void:
	if current_state != STATE_ITEM_USE:
		return
	_emit_item_use_progress(false)
	_cancel_pending_use()
	_transition_to(STATE_FOCUS if interaction_driver.has_valid_focus() else STATE_NONE)


func _update_instant_use(delta: float) -> void:
	var timing: ActionTimingDefinition = _interaction_timing()
	_action_elapsed = minf(timing.total_seconds(), _action_elapsed + maxf(0.0, delta))
	_resolve_instant_use_if_due()
	if _action_elapsed >= timing.total_seconds():
		_cancel_pending_use()
		_transition_to(STATE_FOCUS if interaction_driver.has_valid_focus() else STATE_NONE)


func _update_held_item_use(input_reader: PlayerInputReader, delta: float) -> void:
	if not input_reader.wants_primary_attack and not _action_resolved:
		cancel_held_item_use()
		return
	var timing: ActionTimingDefinition = _interaction_timing()
	if not _action_resolved:
		_action_elapsed = minf(timing.total_seconds(), _action_elapsed + maxf(0.0, delta))
		_resolve_instant_use_if_due()
		_emit_item_use_progress(not _action_resolved)
	if _action_elapsed < timing.total_seconds():
		return
	_cancel_pending_use()
	_transition_to(STATE_FOCUS if interaction_driver.has_valid_focus() else STATE_NONE)


func _resolve_instant_use_if_due() -> void:
	if _action_resolved or _pending_actor == null:
		return
	if _action_elapsed < _interaction_timing().impact_start_seconds():
		return
	_action_resolved = true
	if _is_item_use_pending():
		if _pending_actor.has_method("resolve_item_use"):
			_pending_actor.call("resolve_item_use", _pending_item_id)
		return
	if _pending_target == null or not is_instance_valid(_pending_target):
		_cancel_pending_use()
		_transition_to(STATE_NONE)
		return
	interaction_driver.interact_target(_pending_target, _pending_actor)


func _cancel_pending_use() -> void:
	_pending_actor = null
	_pending_target = null
	_pending_item_id = &""
	_action_elapsed = 0.0
	_action_resolved = false


func _interaction_timing() -> ActionTimingDefinition:
	if combat_definition != null and combat_definition.interact_timing != null:
		return combat_definition.interact_timing
	return ActionTimingDefinition.new()


func _is_holding() -> bool:
	return current_state in [STATE_HOLD_USE, STATE_LOOTING, STATE_HARVESTING, STATE_REPAIRING]


func _emit_item_use_progress(active: bool) -> void:
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	var duration: float = _interaction_timing().impact_start_seconds()
	var progress: float = 1.0 if duration <= 0.0 else clampf(_action_elapsed / duration, 0.0, 1.0)
	event_bus.item_use_progress.emit(_pending_item_id, progress, active)


func _is_item_use_pending() -> bool:
	return _pending_item_id != &""


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

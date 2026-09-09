class_name PlayerWatchStateMachine
extends Node

signal state_changed(active: bool)

const STATE_HIDDEN: StringName = &"hidden"
const STATE_INSPECTING: StringName = &"inspecting"

var current_state: StringName = STATE_HIDDEN
var _event_bus = null


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")


func update() -> Dictionary:
	var active: bool = is_active()
	return {
		"watch_active": active,
		"combat_blocked": active,
		"interaction_blocked": active,
		"mobility_blocked": active,
	}


func toggle() -> void:
	_transition_to(STATE_HIDDEN if is_active() else STATE_INSPECTING)


func close() -> void:
	_transition_to(STATE_HIDDEN)


func is_active() -> bool:
	return current_state == STATE_INSPECTING


func _transition_to(next_state: StringName) -> void:
	if current_state == next_state:
		return

	current_state = next_state
	var active: bool = current_state == STATE_INSPECTING
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	state_changed.emit(active)
	if _event_bus != null:
		_event_bus.watch_state_changed.emit(active)

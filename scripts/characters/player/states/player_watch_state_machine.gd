class_name PlayerWatchStateMachine
extends Node

signal state_changed(active: bool)

const STATE_HIDDEN: StringName = &"hidden"
const STATE_INSPECTING: StringName = &"inspecting"

var current_state: StringName = STATE_HIDDEN
var _event_bus = null


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")


func update(input_reader: PlayerInputReader) -> Dictionary:
	var active: bool = input_reader.wants_watch
	_transition_to(STATE_INSPECTING if active else STATE_HIDDEN)
	return {
		"watch_active": active,
		"combat_blocked": active,
		"interaction_blocked": active,
		"mobility_blocked": active,
	}


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

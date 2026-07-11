extends Node

const PHASE_DAYLIGHT: StringName = &"daylight"
const PHASE_PREPARATION: StringName = &"preparation"
const PHASE_RAIN: StringName = &"rain"
const PHASE_SETTLEMENT: StringName = &"settlement"
const PHASE_COMPLETE: StringName = &"complete"
const PHASE_FAILED: StringName = &"failed"

const _KEY_ACTIONS: Dictionary[StringName, Key] = {
	&"move_forward": KEY_W,
	&"move_back": KEY_S,
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"sprint": KEY_SHIFT,
	&"slide": KEY_CTRL,
	&"block": KEY_Q,
	&"shove": KEY_F,
	&"interact": KEY_E,
	&"reload": KEY_R,
	&"use_consumable": KEY_C,
	&"switch_weapon": KEY_TAB,
	&"debug_restart": KEY_F5,
}

const _MOUSE_ACTIONS: Dictionary[StringName, MouseButton] = {
	&"light_attack": MOUSE_BUTTON_LEFT,
	&"heavy_attack": MOUSE_BUTTON_RIGHT,
}

var current_run_id: StringName = &"none"
var current_phase: StringName = PHASE_DAYLIGHT
var current_wave_index: int = 0
var active_run_config: RunConfig


func _ready() -> void:
	_ensure_default_input_map()


func start_mvp_run(config: RunConfig = null) -> void:
	active_run_config = config
	current_run_id = &"mvp"
	current_wave_index = 1
	current_phase = PHASE_DAYLIGHT
	var event_bus = _event_bus()
	if event_bus != null:
		event_bus.run_started.emit(current_run_id)
		event_bus.phase_changed.emit(&"none", current_phase, current_wave_index)


func change_phase(next_phase: StringName) -> void:
	if next_phase == current_phase:
		return

	var previous_phase: StringName = current_phase
	current_phase = next_phase
	var event_bus = _event_bus()
	if event_bus != null:
		event_bus.phase_changed.emit(previous_phase, current_phase, current_wave_index)


func advance_wave() -> void:
	current_wave_index += 1
	change_phase(PHASE_DAYLIGHT)


func fail_run(reason: StringName) -> void:
	change_phase(PHASE_FAILED)
	var event_bus = _event_bus()
	if event_bus != null:
		event_bus.run_failed.emit(reason)


func complete_run(ending_id: StringName = &"mvp_fake_ending") -> void:
	change_phase(PHASE_COMPLETE)
	var event_bus = _event_bus()
	if event_bus != null:
		event_bus.run_completed.emit(ending_id)


func _ensure_default_input_map() -> void:
	for action_name: StringName in _KEY_ACTIONS.keys():
		_ensure_key_action(action_name, _KEY_ACTIONS[action_name])

	for action_name: StringName in _MOUSE_ACTIONS.keys():
		_ensure_mouse_action(action_name, _MOUSE_ACTIONS[action_name])


func _ensure_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if not InputMap.action_get_events(action_name).is_empty():
		return

	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _ensure_mouse_action(action_name: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if not InputMap.action_get_events(action_name).is_empty():
		return

	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)


func _event_bus() -> Node:
	return get_node_or_null("/root/EventBus")

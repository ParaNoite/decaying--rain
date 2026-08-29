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
	&"jump": KEY_SPACE,
	&"sprint": KEY_SHIFT,
	&"slide": KEY_CTRL,
	&"watch": KEY_TAB,
	&"parry": KEY_Q,
	&"shove": KEY_F,
	&"active_skill": KEY_X,
	&"interact": KEY_E,
	&"reload": KEY_R,
	&"attack_secondary": KEY_C,
	&"inventory": KEY_I,
	&"inventory_slot_1": KEY_1,
	&"inventory_slot_2": KEY_2,
	&"inventory_slot_3": KEY_3,
	&"inventory_slot_4": KEY_4,
	&"inventory_drop": KEY_Z,
	&"inventory_clear_selection": KEY_H,
	&"pause": KEY_ESCAPE,
	&"debug_restart": KEY_F5,
	&"debug_god_mode": KEY_9,
}

const _MOUSE_ACTIONS: Dictionary[StringName, MouseButton] = {
	&"attack_primary": MOUSE_BUTTON_LEFT,
	&"attack_secondary": MOUSE_BUTTON_RIGHT,
	&"weapon_next": MOUSE_BUTTON_WHEEL_UP,
	&"weapon_previous": MOUSE_BUTTON_WHEEL_DOWN,
}

const _LEGACY_ACTION_ALIASES: Dictionary[StringName, StringName] = {
	&"block": &"parry",
	&"light_attack": &"attack_primary",
	&"heavy_attack": &"attack_secondary",
	&"switch_weapon": &"weapon_next",
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

	_ensure_legacy_action_aliases()


func _ensure_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if _action_has_key_event(action_name, keycode):
		return

	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _ensure_mouse_action(action_name: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	if _action_has_mouse_event(action_name, button):
		return

	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)


func _ensure_legacy_action_aliases() -> void:
	for alias_name: StringName in _LEGACY_ACTION_ALIASES.keys():
		var source_name: StringName = _LEGACY_ACTION_ALIASES[alias_name]
		if not InputMap.has_action(alias_name):
			InputMap.add_action(alias_name)
		if not InputMap.action_get_events(alias_name).is_empty():
			continue
		for event: InputEvent in InputMap.action_get_events(source_name):
			InputMap.action_add_event(alias_name, event.duplicate())


func _action_has_key_event(action_name: StringName, keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == keycode:
				return true
	return false


func _action_has_mouse_event(action_name: StringName, button: MouseButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event as InputEventMouseButton
			if mouse_event.button_index == button:
				return true
	return false


func _event_bus() -> Node:
	return get_node_or_null("/root/EventBus")

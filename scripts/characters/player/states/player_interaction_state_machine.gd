class_name PlayerInteractionStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_NONE: StringName = &"none"
const STATE_FOCUS: StringName = &"focus"
const STATE_INSTANT_USE: StringName = &"instant_use"
const STATE_DISABLED: StringName = &"disabled"

@export var interaction_driver_path: NodePath = ^"../../InteractionDriver"

@onready var interaction_driver: PlayerInteractionDriver = get_node(interaction_driver_path)

var current_state: StringName = STATE_NONE
var _use_flash_time: float = 0.0


func update(actor: Node, input_reader: PlayerInputReader, constraints: Dictionary, delta: float) -> void:
	if constraints.get("interaction_blocked", false):
		input_reader.consume_interact()
		interaction_driver.clear_prompt()
		_transition_to(STATE_DISABLED)
		return

	if current_state == STATE_DISABLED:
		_transition_to(STATE_NONE)

	interaction_driver.refresh_focus()

	if _use_flash_time > 0.0:
		_use_flash_time = maxf(0.0, _use_flash_time - delta)

	if input_reader.consume_interact():
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


func _transition_to(next_state: StringName) -> void:
	if current_state == next_state:
		return

	var previous_state: StringName = current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)

class_name PlayerConditionStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_NORMAL: StringName = &"normal"
const STATE_HUNGRY: StringName = &"hungry"
const STATE_EXHAUSTED: StringName = &"exhausted"
const STATE_BLEEDING: StringName = &"bleeding"
const STATE_STAGGERED: StringName = &"staggered"
const STATE_DEAD: StringName = &"dead"

@export var health_path: NodePath = ^"../../Components/HealthComponent"
@export var stamina_path: NodePath = ^"../../Components/StaminaComponent"
@export var hunger_path: NodePath = ^"../../Components/HungerComponent"
@export var status_container_path: NodePath = ^"../../Components/StatusContainer"

@onready var health: HealthComponent = get_node(health_path)
@onready var stamina: StaminaComponent = get_node(stamina_path)
@onready var hunger: HungerComponent = get_node(hunger_path)
@onready var status_container: StatusContainer = get_node(status_container_path)

var current_state: StringName = STATE_NORMAL


func _ready() -> void:
	if health != null:
		health.died.connect(_on_died)


func update(base_constraints: Dictionary = {}) -> Dictionary:
	var constraints: Dictionary = base_constraints.duplicate(true)

	if health != null and not health.is_alive():
		_transition_to(STATE_DEAD)
		constraints["movement_disabled"] = true
		constraints["combat_blocked"] = true
		constraints["interaction_blocked"] = true
		constraints["mobility_blocked"] = true
		return constraints

	if status_container != null and status_container.has_status(&"staggered"):
		_transition_to(STATE_STAGGERED)
	elif status_container != null and status_container.has_status(&"bleeding"):
		_transition_to(STATE_BLEEDING)
	elif status_container != null and status_container.has_status(&"exhausted"):
		_transition_to(STATE_EXHAUSTED)
	elif status_container != null and status_container.has_status(&"hungry"):
		_transition_to(STATE_HUNGRY)
	else:
		_transition_to(STATE_NORMAL)

	return constraints


func _on_died() -> void:
	_transition_to(STATE_DEAD)


func _transition_to(next_state: StringName) -> void:
	if current_state == next_state:
		return

	var previous_state: StringName = current_state
	current_state = next_state
	state_changed.emit(previous_state, current_state)

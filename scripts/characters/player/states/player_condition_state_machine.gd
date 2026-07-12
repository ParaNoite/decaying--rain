class_name PlayerConditionStateMachine
extends Node

signal state_changed(previous_state: StringName, current_state: StringName)

const STATE_NORMAL: StringName = &"normal"
const STATE_HUNGRY: StringName = &"hungry"
const STATE_EXHAUSTED: StringName = &"exhausted"
const STATE_DEAD: StringName = &"dead"

@export var health_path: NodePath = ^"../../Components/HealthComponent"
@export var stamina_path: NodePath = ^"../../Components/StaminaComponent"
@export var hunger_path: NodePath = ^"../../Components/HungerComponent"

@onready var health: HealthComponent = get_node(health_path)
@onready var stamina: StaminaComponent = get_node(stamina_path)
@onready var hunger: HungerComponent = get_node(hunger_path)

var current_state: StringName = STATE_NORMAL


func _ready() -> void:
	if health != null:
		health.died.connect(_on_died)


func update() -> Dictionary:
	var constraints: Dictionary = {
		"movement_disabled": false,
		"combat_blocked": false,
		"interaction_blocked": false,
		"mobility_blocked": false,
		"outgoing_damage_multiplier": 1.0,
	}

	if health != null and not health.is_alive():
		_transition_to(STATE_DEAD)
		constraints["movement_disabled"] = true
		constraints["combat_blocked"] = true
		constraints["interaction_blocked"] = true
		constraints["mobility_blocked"] = true
		return constraints

	if stamina != null and stamina.current_stamina <= 0.0:
		_transition_to(STATE_EXHAUSTED)
		constraints["mobility_blocked"] = true
	elif hunger != null and hunger.is_hungry:
		_transition_to(STATE_HUNGRY)
		constraints["outgoing_damage_multiplier"] = 0.75
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

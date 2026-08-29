class_name HungerComponent
extends Node

signal hunger_changed(old_value: float, new_value: float)
signal hunger_state_changed(is_hungry: bool)

@export_range(1.0, 1000.0, 1.0) var max_hunger: float = 100.0
@export_range(0.0, 100.0, 0.1) var decay_per_minute: float = 8.0
@export_range(0.0, 1000.0, 1.0) var hungry_threshold: float = 0.0
@export var broadcast_player_events: bool = false

var current_hunger: float = 100.0
var is_hungry: bool = false


func _ready() -> void:
	current_hunger = max_hunger
	_update_hungry_state()
	_broadcast()


func _process(delta: float) -> void:
	consume_hunger(decay_per_minute / 60.0 * delta)


func consume_hunger(amount: float) -> void:
	if amount <= 0.0:
		return
	set_hunger(current_hunger - amount)


func restore_hunger(amount: float) -> void:
	if amount <= 0.0:
		return
	set_hunger(current_hunger + amount)


func set_hunger(value: float) -> void:
	var old_hunger: float = current_hunger
	current_hunger = clampf(value, 0.0, max_hunger)
	if is_equal_approx(old_hunger, current_hunger):
		return

	hunger_changed.emit(old_hunger, current_hunger)
	_update_hungry_state()
	_broadcast()


func _update_hungry_state() -> void:
	var next_is_hungry: bool = current_hunger <= hungry_threshold
	if next_is_hungry == is_hungry:
		return
	is_hungry = next_is_hungry
	hunger_state_changed.emit(is_hungry)


func _broadcast() -> void:
	if broadcast_player_events:
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.hunger_changed.emit(current_hunger, max_hunger)

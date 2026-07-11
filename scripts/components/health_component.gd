class_name HealthComponent
extends Node

signal health_changed(old_value: float, new_value: float)
signal died

@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export var broadcast_player_events: bool = false
@export var broadcast_base_core_events: bool = false

var current_health: float = 100.0


func _ready() -> void:
	current_health = max_health
	_broadcast()


func take_damage(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return

	var old_health: float = current_health
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(old_health, current_health)
	_broadcast()

	if current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or not is_alive():
		return

	var old_health: float = current_health
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(old_health, current_health)
	_broadcast()


func set_health(value: float) -> void:
	var old_health: float = current_health
	current_health = clampf(value, 0.0, max_health)
	health_changed.emit(old_health, current_health)
	_broadcast()


func is_alive() -> bool:
	return current_health > 0.0


func _broadcast() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	if broadcast_player_events:
		event_bus.player_health_changed.emit(current_health, max_health)
	if broadcast_base_core_events:
		event_bus.base_core_health_changed.emit(current_health, max_health)

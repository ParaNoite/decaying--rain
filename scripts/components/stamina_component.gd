class_name StaminaComponent
extends Node

signal stamina_changed(old_value: float, new_value: float)

@export_range(1.0, 1000.0, 1.0) var max_stamina: float = 100.0
@export_range(0.0, 1000.0, 1.0) var recovery_per_second: float = 25.0
@export var auto_recover: bool = true
@export var broadcast_player_events: bool = false

var current_stamina: float = 100.0


func _ready() -> void:
	current_stamina = max_stamina
	_broadcast()


func _process(delta: float) -> void:
	if auto_recover:
		recover(recovery_per_second * delta)


func can_consume(amount: float) -> bool:
	return amount <= 0.0 or current_stamina >= amount


func consume(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_stamina < amount:
		return false

	var old_stamina: float = current_stamina
	current_stamina = maxf(0.0, current_stamina - amount)
	stamina_changed.emit(old_stamina, current_stamina)
	_broadcast()
	return true


func recover(amount: float) -> void:
	if amount <= 0.0 or current_stamina >= max_stamina:
		return

	var old_stamina: float = current_stamina
	current_stamina = minf(max_stamina, current_stamina + amount)
	stamina_changed.emit(old_stamina, current_stamina)
	_broadcast()


func _broadcast() -> void:
	if broadcast_player_events:
		var event_bus = get_node_or_null("/root/EventBus")
		if event_bus != null:
			event_bus.player_stamina_changed.emit(current_stamina, max_stamina)

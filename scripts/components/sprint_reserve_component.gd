class_name SprintReserveComponent
extends Node

@export_range(1.0, 1000.0, 1.0) var max_reserve: float = 100.0
@export_range(0.0, 1000.0, 1.0) var recovery_per_second: float = 35.0
@export_range(0.0, 10.0, 0.05) var recovery_delay_seconds: float = 0.7

var current_reserve: float = 100.0
var recovery_delay_remaining: float = 0.0


func _ready() -> void:
	current_reserve = max_reserve


func _process(delta: float) -> void:
	if recovery_delay_remaining > 0.0:
		recovery_delay_remaining = maxf(0.0, recovery_delay_remaining - delta)
		return
	recover(recovery_per_second * delta)


func can_consume(amount: float) -> bool:
	return amount <= 0.0 or current_reserve >= amount


func consume(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_reserve <= 0.0:
		return false
	current_reserve = maxf(0.0, current_reserve - amount)
	recovery_delay_remaining = recovery_delay_seconds
	return true


func recover(amount: float) -> void:
	if amount <= 0.0 or current_reserve >= max_reserve:
		return
	current_reserve = minf(max_reserve, current_reserve + amount)

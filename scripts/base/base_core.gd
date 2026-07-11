class_name BaseCore
extends Node3D

@onready var health: HealthComponent = %HealthComponent


func _ready() -> void:
	add_to_group("base_core")
	health.died.connect(_on_died)


func apply_damage(amount: float) -> void:
	health.take_damage(amount)


func repair(amount: float) -> void:
	health.heal(amount)


func _on_died() -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager != null:
		game_manager.fail_run(&"base_core_destroyed")

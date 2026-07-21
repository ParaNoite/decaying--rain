class_name BaseCore
extends Node3D

@onready var health: HealthComponent = %HealthComponent


func _ready() -> void:
	add_to_group("base_core")
	health.died.connect(_on_died)


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var damage: DamageEventData = DamageEventData.new()
	damage.target_id = get_instance_id()
	damage.amount = amount
	damage.damage_type = &"structural"
	damage.source_tags = [&"legacy_apply_damage"]
	damage.bypass_outgoing_modifiers = true
	receive_damage(damage)


func receive_damage(data: DamageEventData) -> void:
	var resolver: Node = get_node_or_null("/root/DamageResolver")
	if resolver != null:
		resolver.call("resolve_damage", data, self)


func get_health_component() -> HealthComponent:
	return health


func repair(amount: float) -> void:
	health.heal(amount)


func _on_died() -> void:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager != null:
		game_manager.fail_run(&"base_core_destroyed")

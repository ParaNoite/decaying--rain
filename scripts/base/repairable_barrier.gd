class_name RepairableBarrier
extends StaticBody3D

signal destroyed
signal repaired

@export var barrier_id: StringName = &"barrier"
@export_range(0.0, 1000.0, 1.0) var repair_amount_per_material: float = 25.0
@export var required_material_id: StringName = &"scrap"

@onready var health: HealthComponent = %HealthComponent


func _ready() -> void:
	add_to_group("barrier")
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


func repair(material_quantity: int) -> void:
	if material_quantity <= 0:
		return
	health.heal(repair_amount_per_material * float(material_quantity))
	repaired.emit()


func _on_died() -> void:
	destroyed.emit()

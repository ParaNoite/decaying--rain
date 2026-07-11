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
	health.take_damage(amount)


func repair(material_quantity: int) -> void:
	if material_quantity <= 0:
		return
	health.heal(repair_amount_per_material * float(material_quantity))
	repaired.emit()


func _on_died() -> void:
	destroyed.emit()

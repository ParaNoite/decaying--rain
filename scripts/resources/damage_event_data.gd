class_name DamageEventData
extends Resource

@export var attacker_id: int = 0
@export var target_id: int = 0
@export var amount: float = 0.0
@export var damage_type: StringName = &"physical"
@export var source_tags: Array[StringName] = []
@export var is_critical: bool = false
@export var stagger: float = 0.0
@export var hit_position: Vector3 = Vector3.ZERO


func is_valid_hit() -> bool:
	return target_id != 0 and amount > 0.0

class_name DamageEventData
extends Resource

@export var attacker_id: int = 0
@export var target_id: int = 0
@export var amount: float = 0.0
@export var damage_type: StringName = &"physical"
@export var source_tags: Array[StringName] = []
## Statuses to apply after this hit resolves. This lets attacks and world interactions
## share the same status path without target-specific combat code.
@export var status_ids_to_apply: Array[StringName] = []
@export var is_critical: bool = false
@export_range(1.0, 10.0, 0.05) var critical_multiplier: float = 2.0
@export var stagger: float = 0.0
@export_range(0.0, 30.0, 0.1) var knockback_force: float = 0.0
@export var hit_position: Vector3 = Vector3.ZERO
@export var bypass_outgoing_modifiers: bool = false
@export var bypass_incoming_modifiers: bool = false


func is_valid_hit() -> bool:
	return is_valid_resolution_request()


func is_valid_resolution_request() -> bool:
	return target_id != 0 and (amount > 0.0 or stagger > 0.0)

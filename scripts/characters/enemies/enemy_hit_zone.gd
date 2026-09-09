class_name EnemyHitZone
extends Area3D

@export var hit_zone_id: StringName = &"body"


func get_damage_tags() -> Array[StringName]:
	return [hit_zone_id]

class_name WaveEnemyEntry
extends Resource

@export var enemy_id: StringName = &"enemy"
@export_range(0, 999, 1) var count: int = 1


func is_valid() -> bool:
	return enemy_id != &"" and count > 0

class_name ActiveStatusData
extends RefCounted

var definition: StatusEffectDefinition
var remaining_seconds: float = 0.0
var tick_elapsed: float = 0.0
var source_id: int = 0
var stack_count: int = 1


func _init(
	definition_value: StatusEffectDefinition,
	duration_seconds: float,
	source_instance_id: int,
) -> void:
	definition = definition_value
	remaining_seconds = duration_seconds
	source_id = source_instance_id

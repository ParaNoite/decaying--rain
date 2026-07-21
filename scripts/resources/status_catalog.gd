class_name StatusCatalog
extends Resource

@export var definitions: Array[StatusEffectDefinition] = []


func get_definition(status_id: StringName) -> StatusEffectDefinition:
	for definition: StatusEffectDefinition in definitions:
		if definition != null and definition.status_id == status_id:
			return definition
	return null

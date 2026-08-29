class_name ResourceNode
extends LootContainer

signal looted(payload: Dictionary)

@export var resource_id: StringName = &"resource_node"


func can_loot() -> bool:
	return can_open()


func loot() -> Dictionary[StringName, int]:
	return open()


func open() -> Dictionary[StringName, int]:
	var payload: Dictionary[StringName, int] = super.open()
	if payload.is_empty():
		return payload
	looted.emit(payload)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.resource_looted.emit(resource_id, payload)
	return payload

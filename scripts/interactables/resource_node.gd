class_name ResourceNode
extends Node3D

signal looted(payload: Dictionary)

@export var resource_id: StringName = &"resource_node"
@export var loot_table: LootTableDefinition
@export var one_shot: bool = true

var has_been_looted: bool = false
var _loot_resolver := LootResolver.new()


func can_loot() -> bool:
	return not one_shot or not has_been_looted


func loot() -> Dictionary[StringName, int]:
	var payload: Dictionary[StringName, int] = {}
	if not can_loot():
		return payload

	payload = _loot_resolver.resolve_loot(loot_table)
	has_been_looted = true
	looted.emit(payload)
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.resource_looted.emit(resource_id, payload)
	return payload

class_name ResourceNode
extends Node3D

signal looted(payload: Dictionary)

@export var resource_id: StringName = &"resource_node"
@export var loot_table: LootTableDefinition
@export var one_shot: bool = true

@onready var interactable: InteractableComponent = get_node_or_null("%InteractableComponent")

var has_been_looted: bool = false
var _loot_resolver := LootResolver.new()


func _ready() -> void:
	if interactable != null:
		interactable.interacted.connect(_on_interacted)


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


func _on_interacted(actor: Node) -> void:
	var payload: Dictionary[StringName, int] = loot()
	if not payload.is_empty() and actor != null and actor.has_method("receive_loot"):
		actor.call("receive_loot", payload)
	if interactable != null and not can_loot():
		interactable.enabled = false

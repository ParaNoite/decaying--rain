class_name LootContainer
extends Node3D

signal opened(payload: Dictionary)

const WORLD_PICKUP_SCENE: PackedScene = preload("res://scenes/interactables/world_pickup.tscn")

@export var container_id: StringName = &"loot_container"
@export var loot_table: LootTableDefinition
@export var one_shot: bool = true
@export_range(0.1, 4.0, 0.1) var drop_radius: float = 0.8

@onready var interactable: InteractableComponent = %InteractableComponent

var has_been_opened: bool = false
var _loot_resolver: LootResolver = LootResolver.new()


func _ready() -> void:
	if interactable != null:
		interactable.interacted.connect(_on_interacted)


func can_open() -> bool:
	return not one_shot or not has_been_opened


func open() -> Dictionary[StringName, int]:
	var payload: Dictionary[StringName, int] = {}
	if not can_open():
		return payload
	payload = _loot_resolver.resolve_loot(loot_table)
	has_been_opened = true
	_spawn_pickups(payload)
	opened.emit(payload)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.loot_container_opened.emit(container_id, payload)
	if interactable != null and one_shot:
		interactable.enabled = false
	return payload


func _on_interacted(_actor: Node) -> void:
	open()


func _spawn_pickups(payload: Dictionary[StringName, int]) -> void:
	if loot_table == null:
		return
	var item_ids: Array = payload.keys()
	item_ids.sort()
	for index: int in item_ids.size():
		var item_id: StringName = StringName(item_ids[index])
		var item: ItemDefinition = loot_table.get_item_definition(item_id)
		var quantity: int = int(payload[item_id])
		if item == null or quantity <= 0:
			continue
		var pickup: WorldPickup = WORLD_PICKUP_SCENE.instantiate() as WorldPickup
		pickup.configure(item, quantity)
		add_child(pickup)
		pickup.position = _drop_position(index, item_ids.size())


func _drop_position(index: int, total: int) -> Vector3:
	if total <= 1:
		return Vector3(0.0, 0.45, -drop_radius)
	var angle: float = TAU * float(index) / float(total)
	return Vector3(cos(angle) * drop_radius, 0.45, sin(angle) * drop_radius)

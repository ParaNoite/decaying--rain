class_name PlayerInventoryComponent
extends Node

signal inventory_changed(items: Dictionary)

const AMMO_IDS: Array[StringName] = [&"light_ammo", &"rifle_ammo", &"shells"]

var model: InventoryModel = InventoryModel.new()
var ammo_pickup_multiplier: float = 1.0
var _initialized: bool = false
var _event_bus: Node


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	model.changed.connect(_on_model_changed)


func initialize(starting_item_ids: Array[StringName], pickup_multiplier: float = 1.0) -> void:
	if _initialized:
		return
	_initialized = true
	ammo_pickup_multiplier = maxf(0.0, pickup_multiplier)
	for item_id: StringName in starting_item_ids:
		model.add_item(item_id)
	_broadcast()


func add_item(item_id: StringName, quantity: int = 1, apply_pickup_rules: bool = false) -> void:
	var final_quantity: int = quantity
	if apply_pickup_rules and AMMO_IDS.has(item_id):
		final_quantity = maxi(1, roundi(quantity * ammo_pickup_multiplier))
	model.add_item(item_id, final_quantity)


func add_loot(payload: Dictionary) -> void:
	var adjusted_payload: Dictionary[StringName, int] = {}
	for item_value: Variant in payload.keys():
		var item_id: StringName = StringName(item_value)
		var quantity: int = int(payload[item_value])
		if AMMO_IDS.has(item_id):
			quantity = maxi(1, roundi(quantity * ammo_pickup_multiplier))
		adjusted_payload[item_id] = quantity
	model.add_items(adjusted_payload)


func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	return model.remove_item(item_id, quantity)


func get_quantity(item_id: StringName) -> int:
	return model.get_quantity(item_id)


func get_items() -> Dictionary:
	return model.to_dictionary()


func _on_model_changed(items: Dictionary) -> void:
	inventory_changed.emit(items)
	if _event_bus != null:
		_event_bus.inventory_changed.emit(items)


func _broadcast() -> void:
	_on_model_changed(model.to_dictionary())

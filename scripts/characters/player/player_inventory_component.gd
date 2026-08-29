class_name PlayerInventoryComponent
extends Node

signal inventory_changed(items: Dictionary)
signal special_inventory_changed(items: Dictionary)

const AMMO_IDS: Array[StringName] = [&"light_ammo", &"rifle_ammo", &"shells"]

@export var item_catalog: Array[ItemDefinition] = []
@export_range(1, 12, 1) var slot_count: int = 4

var model: InventoryModel
var ammo_pickup_multiplier: float = 1.0
var _initialized: bool = false
var _event_bus: Node
var _items_by_id: Dictionary[StringName, ItemDefinition] = {}
var special_item_quantities: Dictionary[StringName, int] = {}
var selected_slot_index: int = -1


func _ready() -> void:
	model = InventoryModel.new(slot_count)
	_event_bus = get_node_or_null("/root/EventBus")
	model.changed.connect(_on_model_changed)
	for item: ItemDefinition in item_catalog:
		if item != null and item.item_id != &"":
			_items_by_id[item.item_id] = item
	if _event_bus != null:
		_event_bus.inventory_selection_changed.emit(selected_slot_index)


func initialize(starting_item_ids: Array[StringName], pickup_multiplier: float = 1.0) -> void:
	if _initialized:
		return
	_initialized = true
	ammo_pickup_multiplier = maxf(0.0, pickup_multiplier)
	for item_id: StringName in starting_item_ids:
		add_item(item_id)
	_broadcast()


func add_item(item_id: StringName, quantity: int = 1, apply_pickup_rules: bool = false) -> bool:
	var item: ItemDefinition = get_item_definition(item_id)
	if item == null:
		push_warning("PlayerInventoryComponent.add_item rejected unknown item: %s" % String(item_id))
		return false
	var final_quantity: int = quantity
	if apply_pickup_rules and AMMO_IDS.has(item_id):
		final_quantity = maxi(1, roundi(quantity * ammo_pickup_multiplier))
	if item.slotless:
		special_item_quantities[item_id] = get_quantity(item_id) + final_quantity
		_broadcast_special_inventory()
		return true
	return model.add_item(item, final_quantity)


func add_item_definition(item: ItemDefinition, quantity: int = 1, apply_pickup_rules: bool = false) -> bool:
	if item == null or not is_item_known(item.item_id) or quantity <= 0:
		return false
	return add_item(item.item_id, quantity, apply_pickup_rules)


func add_loot(payload: Dictionary) -> void:
	var adjusted_payload: Dictionary[StringName, int] = {}
	for item_value: Variant in payload.keys():
		var item_id: StringName = StringName(item_value)
		var quantity: int = int(payload[item_value])
		if not is_item_known(item_id) or quantity <= 0:
			continue
		if AMMO_IDS.has(item_id):
			quantity = maxi(1, roundi(quantity * ammo_pickup_multiplier))
		adjusted_payload[item_id] = quantity
	for item_id: StringName in adjusted_payload:
		add_item(item_id, adjusted_payload[item_id])


func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0 or get_quantity(item_id) < quantity:
		return false
	if _is_slotless(item_id):
		var remaining: int = get_quantity(item_id) - quantity
		if remaining > 0:
			special_item_quantities[item_id] = remaining
		else:
			special_item_quantities.erase(item_id)
		_broadcast_special_inventory()
		return true
	return model.remove_item(item_id, quantity)


func get_quantity(item_id: StringName) -> int:
	if _is_slotless(item_id):
		return int(special_item_quantities.get(item_id, 0))
	return model.get_quantity(item_id)


func get_slot_count() -> int:
	return model.slots.size()


func get_slot_snapshots() -> Array[Dictionary]:
	return model.to_slot_snapshots()


func select_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= get_slot_count():
		return false
	selected_slot_index = slot_index
	if _event_bus != null:
		_event_bus.inventory_selection_changed.emit(selected_slot_index)
	return true


func clear_selection() -> void:
	if selected_slot_index < 0:
		return
	selected_slot_index = -1
	if _event_bus != null:
		_event_bus.inventory_selection_changed.emit(selected_slot_index)


func get_selected_item() -> ItemDefinition:
	if selected_slot_index < 0:
		return null
	return get_item_definition(model.get_slot_item_id(selected_slot_index))


func drop_selected_item() -> ItemDefinition:
	if selected_slot_index < 0:
		return null
	var item_id: StringName = model.get_slot_item_id(selected_slot_index)
	var item: ItemDefinition = get_item_definition(item_id)
	if item == null or model.remove_slot_item(selected_slot_index) == &"":
		return null
	return item


func is_item_known(item_id: StringName) -> bool:
	return _items_by_id.has(item_id)


func get_item_definition(item_id: StringName) -> ItemDefinition:
	return _items_by_id.get(item_id) as ItemDefinition


func can_use_item(item_id: StringName) -> bool:
	var item: ItemDefinition = get_item_definition(item_id)
	return item != null and item.has_use_effect() and get_quantity(item_id) > 0


func consume_item(item_id: StringName, quantity: int = 1) -> ItemDefinition:
	var item: ItemDefinition = get_item_definition(item_id)
	if item == null or quantity <= 0 or get_quantity(item_id) < quantity:
		return null
	if not remove_item(item_id, quantity):
		return null
	return item


func get_items() -> Dictionary:
	return model.to_dictionary()


func get_special_items() -> Dictionary:
	return special_item_quantities.duplicate()


func _is_slotless(item_id: StringName) -> bool:
	var item: ItemDefinition = get_item_definition(item_id)
	return item != null and item.slotless


func _on_model_changed(items: Dictionary) -> void:
	inventory_changed.emit(items)
	if _event_bus != null:
		_event_bus.inventory_changed.emit(items)


func _broadcast() -> void:
	_on_model_changed(model.to_dictionary())
	_broadcast_special_inventory()


func _broadcast_special_inventory() -> void:
	var items: Dictionary = get_special_items()
	special_inventory_changed.emit(items)
	if _event_bus != null:
		_event_bus.special_inventory_changed.emit(items)
	# Existing systems use this signal to refresh ammunition reserve counts.
	inventory_changed.emit(model.to_dictionary())
	if _event_bus != null:
		_event_bus.inventory_changed.emit(model.to_dictionary())

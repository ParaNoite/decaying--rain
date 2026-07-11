class_name InventoryModel
extends RefCounted

signal changed(items: Dictionary)

var items: Dictionary[StringName, int] = {}


func add_item(item_id: StringName, quantity: int = 1) -> void:
	if item_id == &"" or quantity <= 0:
		return

	items[item_id] = items.get(item_id, 0) + quantity
	changed.emit(to_dictionary())


func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if item_id == &"" or quantity <= 0:
		return false

	var current_quantity: int = items.get(item_id, 0)
	if current_quantity < quantity:
		return false

	var next_quantity: int = current_quantity - quantity
	if next_quantity <= 0:
		items.erase(item_id)
	else:
		items[item_id] = next_quantity

	changed.emit(to_dictionary())
	return true


func get_quantity(item_id: StringName) -> int:
	return items.get(item_id, 0)


func clear() -> void:
	items.clear()
	changed.emit(to_dictionary())


func to_dictionary() -> Dictionary:
	return items.duplicate(true)

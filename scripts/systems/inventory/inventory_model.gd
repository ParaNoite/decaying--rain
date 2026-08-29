class_name InventoryModel
extends RefCounted

signal changed(items: Dictionary)

class InventorySlot:
	extends RefCounted

	var item_id: StringName = &""
	var quantity: int = 0


	func is_empty() -> bool:
		return item_id == &"" or quantity <= 0


	func clear() -> void:
		item_id = &""
		quantity = 0


var slots: Array[InventorySlot] = []


func _init(slot_count: int = 4) -> void:
	for _index: int in maxi(1, slot_count):
		slots.append(InventorySlot.new())


func can_add_item(item: ItemDefinition, quantity: int = 1) -> bool:
	if item == null or item.item_id == &"" or quantity <= 0:
		return false
	var remaining: int = quantity
	var stack_limit: int = item.get_stack_limit()
	if item.stackable:
		for slot: InventorySlot in slots:
			if slot.item_id != item.item_id:
				continue
			remaining -= mini(remaining, maxi(0, stack_limit - slot.quantity))
			if remaining <= 0:
				return true
	for slot: InventorySlot in slots:
		if not slot.is_empty():
			continue
		remaining -= mini(remaining, stack_limit)
		if remaining <= 0:
			return true
	return false


func add_item(item: ItemDefinition, quantity: int = 1) -> bool:
	if not can_add_item(item, quantity):
		return false
	var remaining: int = quantity
	var stack_limit: int = item.get_stack_limit()
	if item.stackable:
		for slot: InventorySlot in slots:
			if slot.item_id != item.item_id:
				continue
			var added: int = mini(remaining, maxi(0, stack_limit - slot.quantity))
			slot.quantity += added
			remaining -= added
			if remaining <= 0:
				_emit_changed()
				return true
	for slot: InventorySlot in slots:
		if not slot.is_empty():
			continue
		var added: int = mini(remaining, stack_limit)
		slot.item_id = item.item_id
		slot.quantity = added
		remaining -= added
		if remaining <= 0:
			_emit_changed()
			return true
	return false


func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if item_id == &"" or quantity <= 0 or get_quantity(item_id) < quantity:
		return false
	var remaining: int = quantity
	for index: int in range(slots.size() - 1, -1, -1):
		var slot: InventorySlot = slots[index]
		if slot.item_id != item_id:
			continue
		var removed: int = mini(remaining, slot.quantity)
		slot.quantity -= removed
		remaining -= removed
		if slot.quantity <= 0:
			slot.clear()
		if remaining <= 0:
			_emit_changed()
			return true
	return false


func remove_slot_item(slot_index: int, quantity: int = 1) -> StringName:
	if slot_index < 0 or slot_index >= slots.size() or quantity <= 0:
		return &""
	var slot: InventorySlot = slots[slot_index]
	if slot.is_empty() or slot.quantity < quantity:
		return &""
	var item_id: StringName = slot.item_id
	slot.quantity -= quantity
	if slot.quantity <= 0:
		slot.clear()
	_emit_changed()
	return item_id


func get_quantity(item_id: StringName) -> int:
	var total: int = 0
	for slot: InventorySlot in slots:
		if slot.item_id == item_id:
			total += slot.quantity
	return total


func get_slot_item_id(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= slots.size():
		return &""
	return slots[slot_index].item_id


func to_dictionary() -> Dictionary:
	var items: Dictionary[StringName, int] = {}
	for slot: InventorySlot in slots:
		if slot.is_empty():
			continue
		items[slot.item_id] = items.get(slot.item_id, 0) + slot.quantity
	return items


func to_slot_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for slot: InventorySlot in slots:
		snapshots.append({"item_id": slot.item_id, "quantity": slot.quantity})
	return snapshots


func _emit_changed() -> void:
	changed.emit(to_dictionary())

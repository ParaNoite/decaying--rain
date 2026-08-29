class_name LootTableDefinition
extends Resource

@export var table_id: StringName = &"loot_table"
@export var entries: Array[LootEntryDefinition] = []
@export var guaranteed_items: Array[ItemDefinition] = []


func get_item_definition(item_id: StringName) -> ItemDefinition:
	if item_id == &"":
		return null
	for item: ItemDefinition in guaranteed_items:
		if item != null and item.item_id == item_id:
			return item
	for entry: LootEntryDefinition in entries:
		if entry != null and entry.item != null and entry.item.item_id == item_id:
			return entry.item
	return null

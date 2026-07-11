class_name LootTableDefinition
extends Resource

@export var table_id: StringName = &"loot_table"
@export var entries: Array[LootEntryDefinition] = []
@export var guaranteed_item_ids: Array[StringName] = []

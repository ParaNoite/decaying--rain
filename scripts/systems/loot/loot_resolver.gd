class_name LootResolver
extends Node


func resolve_loot(table: LootTableDefinition, random: RandomNumberGenerator = null) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	if table == null:
		return result

	var rng: RandomNumberGenerator = random
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	for item: ItemDefinition in table.guaranteed_items:
		if item != null and item.item_id != &"":
			result[item.item_id] = result.get(item.item_id, 0) + 1

	for entry: LootEntryDefinition in table.entries:
		if entry == null:
			continue
		if rng.randf() > entry.drop_chance:
			continue

		var item_id: StringName = entry.get_item_id()
		var quantity: int = entry.get_quantity(rng)
		if item_id == &"" or quantity <= 0:
			continue
		result[item_id] = result.get(item_id, 0) + quantity

	return result

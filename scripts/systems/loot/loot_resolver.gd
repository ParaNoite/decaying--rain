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

	for item_id: StringName in table.guaranteed_item_ids:
		result[item_id] = result.get(item_id, 0) + 1

	for entry: LootEntryDefinition in table.entries:
		if entry == null:
			continue
		if rng.randf() > entry.drop_chance:
			continue

		var quantity: int = entry.get_quantity(rng)
		if quantity <= 0:
			continue
		result[entry.item_id] = result.get(entry.item_id, 0) + quantity

	return result

class_name LootEntryDefinition
extends Resource

@export var item_id: StringName = &"item"
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0
@export_range(0, 999, 1) var min_quantity: int = 1
@export_range(0, 999, 1) var max_quantity: int = 1
@export var tags: Array[StringName] = []


func get_quantity(random: RandomNumberGenerator) -> int:
	if max_quantity <= min_quantity:
		return min_quantity
	return random.randi_range(min_quantity, max_quantity)

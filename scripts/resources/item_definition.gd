class_name ItemDefinition
extends Resource

enum ItemKind {
	CONSUMABLE,
	AMMO,
	MATERIAL,
}

enum VisualKind {
	DEFAULT,
	BANDAGE,
	MEDKIT,
	FOOD,
}

@export_group("Identity")
@export var item_id: StringName = &"item"
@export var display_name: String = "Item"
@export_multiline var description: String = ""
@export var item_kind: ItemKind = ItemKind.MATERIAL
@export var stackable: bool = false
@export_range(1, 999, 1) var max_stack_size: int = 99
@export var slotless: bool = false
@export var visual_kind: VisualKind = VisualKind.DEFAULT

@export_group("Use Effect")
@export var usable: bool = false
@export_range(0.0, 1000.0, 1.0) var health_restore: float = 0.0
@export_range(0.0, 1000.0, 1.0) var hunger_restore: float = 0.0
@export var clears_bleeding: bool = false


func has_use_effect() -> bool:
	return usable and (health_restore > 0.0 or hunger_restore > 0.0 or clears_bleeding)


func get_stack_limit() -> int:
	return max_stack_size if stackable else 1

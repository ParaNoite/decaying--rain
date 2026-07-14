class_name InteractableComponent
extends Area3D

signal interacted(actor: Node)

enum InteractionKind {
	INSTANT,
	LOOT,
	HARVEST,
	REPAIR,
}

@export var prompt: String = "Interact"
@export var enabled: bool = true
@export var interaction_kind: InteractionKind = InteractionKind.INSTANT
@export_range(0.0, 10.0, 0.1) var hold_duration: float = 0.0


func interact(actor: Node) -> void:
	if not enabled:
		return
	interacted.emit(actor)


func get_action_id() -> StringName:
	match interaction_kind:
		InteractionKind.LOOT:
			return &"loot"
		InteractionKind.HARVEST:
			return &"harvest"
		InteractionKind.REPAIR:
			return &"repair"
		_:
			return &"interact"

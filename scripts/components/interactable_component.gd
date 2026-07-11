class_name InteractableComponent
extends Area3D

signal interacted(actor: Node)

@export var prompt: String = "Interact"
@export var enabled: bool = true


func interact(actor: Node) -> void:
	if not enabled:
		return
	interacted.emit(actor)

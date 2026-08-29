class_name PlayerInteractionDriver
extends Node

@export var raycast_path: NodePath = ^"../Head/InteractionRayCast3D"
@export var focus_group: StringName = &"interactable"

@onready var raycast: RayCast3D = get_node(raycast_path)

var focused_interactable: InteractableComponent
var _event_bus = null


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")


func refresh_focus() -> void:
	if focused_interactable != null and not is_instance_valid(focused_interactable):
		focused_interactable = null
	var next_focus: InteractableComponent = _find_focus()
	if next_focus == focused_interactable:
		return

	focused_interactable = next_focus
	_emit_prompt(_prompt_for_focus())


func interact(actor: Node) -> void:
	refresh_focus()
	if not has_valid_focus():
		return

	focused_interactable.interact(actor)


func interact_target(target: InteractableComponent, actor: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.interact(actor)


func has_valid_focus() -> bool:
	return focused_interactable != null and is_instance_valid(focused_interactable) and focused_interactable.enabled


func get_focus_action_id() -> StringName:
	if not has_valid_focus():
		return &"interact"
	return focused_interactable.get_action_id()


func get_focus_hold_duration() -> float:
	if not has_valid_focus():
		return 0.0
	return focused_interactable.hold_duration


func update_hold_prompt(elapsed: float) -> void:
	if not has_valid_focus():
		return
	var duration: float = maxf(0.01, focused_interactable.hold_duration)
	var progress: int = clampi(roundi(elapsed / duration * 100.0), 0, 100)
	_emit_prompt("%s  %d%%" % [focused_interactable.prompt, progress])


func clear_prompt() -> void:
	focused_interactable = null
	_emit_prompt("")


func restore_prompt() -> void:
	_emit_prompt(_prompt_for_focus())


func _find_focus() -> InteractableComponent:
	if raycast == null or not raycast.is_colliding():
		return null

	var collider: Object = raycast.get_collider()
	if collider is InteractableComponent:
		return collider as InteractableComponent

	if collider is Node:
		var node: Node = collider as Node
		for child: Node in node.get_children():
			if child is InteractableComponent:
				return child as InteractableComponent

	return null


func _prompt_for_focus() -> String:
	if not has_valid_focus():
		return ""
	return focused_interactable.prompt


func _emit_prompt(prompt: String) -> void:
	if _event_bus != null:
		_event_bus.interaction_prompt_changed.emit(prompt)

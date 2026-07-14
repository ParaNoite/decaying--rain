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
	var next_focus: InteractableComponent = _find_focus()
	if next_focus == focused_interactable:
		return

	focused_interactable = next_focus
	_emit_prompt(_prompt_for_focus())


func interact(actor: Node) -> void:
	refresh_focus()
	if focused_interactable == null:
		return

	focused_interactable.interact(actor)


func get_focus_action_id() -> StringName:
	if focused_interactable == null:
		return &"interact"
	return focused_interactable.get_action_id()


func get_focus_hold_duration() -> float:
	if focused_interactable == null:
		return 0.0
	return focused_interactable.hold_duration


func update_hold_prompt(elapsed: float) -> void:
	if focused_interactable == null:
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
	if focused_interactable == null or not focused_interactable.enabled:
		return ""
	return focused_interactable.prompt


func _emit_prompt(prompt: String) -> void:
	if _event_bus != null:
		_event_bus.interaction_prompt_changed.emit(prompt)

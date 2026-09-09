class_name WorldPickup
extends RigidBody3D

signal picked_up(item: ItemDefinition, quantity: int)

@export var item: ItemDefinition
@export_range(1, 999, 1) var quantity: int = 1

@onready var interactable: InteractableComponent = %InteractableComponent
@onready var visual: MeshInstance3D = $Visual

var _pending_impulse: Vector3 = Vector3.ZERO
var _settle_requested: bool = false


func _ready() -> void:
	_configure_visual()
	if interactable != null:
		interactable.prompt = _prompt_text()
		interactable.interacted.connect(_on_interacted)
	body_entered.connect(_on_world_contact)
	if not _pending_impulse.is_zero_approx():
		apply_central_impulse(_pending_impulse)
		_pending_impulse = Vector3.ZERO


func configure(next_item: ItemDefinition, next_quantity: int) -> void:
	item = next_item
	quantity = maxi(1, next_quantity)
	_configure_visual()
	if interactable != null:
		interactable.prompt = _prompt_text()


func launch(impulse: Vector3) -> void:
	if impulse.is_zero_approx():
		return
	freeze = false
	sleeping = false
	_settle_requested = false
	if is_inside_tree():
		apply_central_impulse(impulse)
		return
	_pending_impulse = impulse


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _settle_requested:
		return
	_settle_requested = false
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	freeze = true


func _on_world_contact(_body: Node) -> void:
	if freeze:
		return
	_settle_requested = true


func _on_interacted(actor: Node) -> void:
	if item == null or quantity <= 0 or actor == null or not actor.has_method("receive_item"):
		return
	if not bool(actor.call("receive_item", item, quantity)):
		return
	picked_up.emit(item, quantity)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.world_item_picked_up.emit(item.item_id, quantity)
	queue_free()


func _prompt_text() -> String:
	if item == null:
		return "Pick up item"
	return "Pick up %s x%d" % [item.display_name, quantity]


func _configure_visual() -> void:
	if visual == null or item == null:
		return
	var material := StandardMaterial3D.new()
	material.roughness = 0.72
	material.metallic = 0.0
	match item.visual_kind:
		ItemDefinition.VisualKind.BANDAGE:
			var bandage_mesh := BoxMesh.new()
			bandage_mesh.size = Vector3(0.30, 0.10, 0.16)
			visual.mesh = bandage_mesh
			material.albedo_color = Color(0.84, 0.80, 0.68, 1.0)
		ItemDefinition.VisualKind.MEDKIT:
			var medkit_mesh := BoxMesh.new()
			medkit_mesh.size = Vector3(0.34, 0.20, 0.24)
			visual.mesh = medkit_mesh
			material.albedo_color = Color(0.72, 0.10, 0.10, 1.0)
		ItemDefinition.VisualKind.FOOD:
			var food_mesh := CylinderMesh.new()
			food_mesh.top_radius = 0.12
			food_mesh.bottom_radius = 0.12
			food_mesh.height = 0.22
			visual.mesh = food_mesh
			material.albedo_color = Color(0.72, 0.48, 0.16, 1.0)
		_:
			var default_mesh := SphereMesh.new()
			default_mesh.radius = 0.16
			default_mesh.height = 0.32
			visual.mesh = default_mesh
			material.albedo_color = Color(0.95, 0.80, 0.26, 1.0)
	visual.material_override = material

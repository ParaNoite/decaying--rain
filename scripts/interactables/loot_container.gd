class_name LootContainer
extends Node3D

signal opened(payload: Dictionary)

const WORLD_PICKUP_SCENE: PackedScene = preload("res://scenes/interactables/world_pickup.tscn")

enum LootContainerVisualKind {
	WOOD_CRATE,
	METAL_CACHE,
}

@export var container_id: StringName = &"loot_container"
@export var loot_table: LootTableDefinition
@export var one_shot: bool = true
@export_range(0.1, 4.0, 0.1) var drop_radius: float = 0.8
@export var visual_kind: LootContainerVisualKind = LootContainerVisualKind.WOOD_CRATE

@onready var interactable: InteractableComponent = %InteractableComponent
@onready var container_mesh: MeshInstance3D = $ContainerMesh

var has_been_opened: bool = false
var _loot_resolver: LootResolver = LootResolver.new()


func _ready() -> void:
	_configure_visual()
	if interactable != null:
		interactable.interacted.connect(_on_interacted)


func can_open() -> bool:
	return not one_shot or not has_been_opened


func open() -> Dictionary[StringName, int]:
	var payload: Dictionary[StringName, int] = {}
	if not can_open():
		return payload
	payload = _loot_resolver.resolve_loot(loot_table)
	has_been_opened = true
	_spawn_pickups(payload)
	opened.emit(payload)
	var event_bus: Node = get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.loot_container_opened.emit(container_id, payload)
	if interactable != null and one_shot:
		interactable.enabled = false
	return payload


func _on_interacted(_actor: Node) -> void:
	open()


func _spawn_pickups(payload: Dictionary[StringName, int]) -> void:
	if loot_table == null:
		return
	var item_ids: Array = payload.keys()
	item_ids.sort()
	for index: int in item_ids.size():
		var item_id: StringName = StringName(item_ids[index])
		var item: ItemDefinition = loot_table.get_item_definition(item_id)
		var quantity: int = int(payload[item_id])
		if item == null or quantity <= 0:
			continue
		var pickup: WorldPickup = WORLD_PICKUP_SCENE.instantiate() as WorldPickup
		pickup.configure(item, quantity)
		var world_parent: Node = get_tree().current_scene if get_tree().current_scene != null else self
		world_parent.add_child(pickup)
		pickup.global_position = global_position + _drop_position(index, item_ids.size())
		var radial_direction: Vector3 = _drop_position(index, item_ids.size()).normalized()
		pickup.launch(radial_direction * 0.35 + Vector3.UP * 0.55)


func _drop_position(index: int, total: int) -> Vector3:
	if total <= 1:
		return Vector3(0.0, 0.45, -drop_radius)
	var angle: float = TAU * float(index) / float(total)
	return Vector3(cos(angle) * drop_radius, 0.45, sin(angle) * drop_radius)


func _configure_visual() -> void:
	if container_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.roughness = 0.78
	var mesh := BoxMesh.new()
	match visual_kind:
		LootContainerVisualKind.METAL_CACHE:
			mesh.size = Vector3(0.95, 0.58, 0.68)
			material.albedo_color = Color(0.30, 0.37, 0.41, 1.0)
			material.metallic = 0.72
			material.roughness = 0.43
		_:
			mesh.size = Vector3(0.9, 0.6, 0.65)
			material.albedo_color = Color(0.34, 0.20, 0.10, 1.0)
			material.metallic = 0.0
	container_mesh.mesh = mesh
	container_mesh.material_override = material

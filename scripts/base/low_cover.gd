class_name LowCover
extends StaticBody3D

signal destroyed(cover_id: StringName)

@export var cover_id: StringName = &"low_cover"

@onready var health: HealthComponent = %HealthComponent
@onready var collision: CollisionShape3D = %CollisionShape3D
@onready var mesh: MeshInstance3D = %CoverMesh


func _ready() -> void:
	add_to_group("low_cover")
	health.died.connect(_on_health_died)


func receive_damage(data: DamageEventData) -> void:
	var resolver: Node = get_node_or_null("/root/DamageResolver")
	if resolver != null:
		resolver.call("resolve_damage", data, self)


func get_health_component() -> HealthComponent:
	return health


func _on_health_died() -> void:
	mesh.visible = false
	collision.set_deferred("disabled", true)
	destroyed.emit(cover_id)

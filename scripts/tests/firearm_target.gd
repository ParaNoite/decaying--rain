extends Node3D

signal hit_report(text: String)

@export var moving: bool = false
var _health: HealthComponent
var _label: Label3D
var _origin: Vector3
var _elapsed: float = 0.0
var _flash: float = 0.0


func _ready() -> void:
	_origin = position
	_health = HealthComponent.new()
	_health.max_health = 1000.0
	add_child(_health)
	_add_zone(&"body", Vector3(0, 1.2, 0), Vector3(0.65, 0.75, 0.2), Color(0.22, 0.65, 0.65))
	_add_zone(&"headshot", Vector3(0, 1.8, 0), Vector3(0.32, 0.32, 0.2), Color(0.95, 0.65, 0.22))
	for side: float in [-1.0, 1.0]:
		_add_zone(&"limb", Vector3(side * 0.22, 0.55, 0), Vector3(0.2, 0.5, 0.2), Color(0.32, 0.42, 0.52))
	_label = Label3D.new()
	_label.position.y = 2.3
	_label.font_size = 40
	_label.pixel_size = 0.008
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.text = "移动靶" if moving else "部位靶"
	add_child(_label)


func _process(delta: float) -> void:
	_elapsed += delta
	if moving:
		position.x = _origin.x + sin(_elapsed * 1.25) * 2.0
	_flash = maxf(0.0, _flash - delta)
	_label.modulate = Color(1, 0.65, 0.2) if _flash > 0.0 else Color.WHITE


func _add_zone(id: StringName, offset: Vector3, size: Vector3, color: Color) -> void:
	var zone: EnemyHitZone = EnemyHitZone.new()
	zone.hit_zone_id = id
	zone.collision_layer = 4
	zone.collision_mask = 0
	zone.position = offset
	add_child(zone)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	zone.add_child(shape)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	visual.material_override = material
	zone.add_child(visual)


func get_health_component() -> HealthComponent:
	return _health


func get_hit_zone_damage_multiplier(tags: Array[StringName]) -> float:
	if tags.has(&"headshot"):
		return 2.0
	return 0.75 if tags.has(&"limb") else 1.0


func receive_damage(data: DamageEventData) -> void:
	get_node("/root/DamageResolver").resolve_damage(data, self)


func on_damage_resolved(result: DamageResolutionData) -> void:
	if not result.applied:
		return
	var zone: String = "头部" if result.event.source_tags.has(&"headshot") else ("肢体" if result.event.source_tags.has(&"limb") else "躯干")
	_label.text = "%s  %.1f" % [zone, result.final_amount]
	_flash = 0.2
	hit_report.emit("%s：%.1f 伤害" % [zone, result.final_amount])
	_health.set_health(_health.max_health)

class_name TemporaryWoodenDummy
extends StaticBody3D

# Temporary MVP test target only.
# Do not use this as an enemy template. Real enemies must follow the dedicated enemy system.

@export_range(1.0, 1000.0, 1.0) var max_health: float = 120.0
@export var destroyed_material: StandardMaterial3D
@export var hurt_material: StandardMaterial3D

@onready var label: Label3D = %StatusLabel
@onready var body_mesh: MeshInstance3D = %BodyMesh

var current_health: float = 120.0
var _event_bus = null
var _default_material: Material


func _ready() -> void:
	add_to_group("enemy")
	_event_bus = get_node_or_null("/root/EventBus")
	current_health = max_health
	_default_material = body_mesh.material_override
	_update_label("READY")
	_emit_notice("Temporary wooden dummy ready: HP %.0f / %.0f" % [current_health, max_health], &"dummy")


func receive_damage(data: DamageEventData) -> void:
	if data == null:
		return

	if data.amount <= 0.0:
		_update_label("HIT: stagger %.1f" % data.stagger)
		_emit_notice("Dummy shoved/staggered: HP %.0f / %.0f" % [current_health, max_health], &"dummy")
		return

	_apply_damage(data.amount)
	if _event_bus != null:
		_event_bus.combat_hit.emit(data)


func apply_damage(amount: float) -> void:
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	if current_health <= 0.0:
		return

	current_health = maxf(0.0, current_health - amount)
	if current_health <= 0.0:
		_update_label("DESTROYED")
		if destroyed_material != null:
			body_mesh.material_override = destroyed_material
		_emit_notice("Dummy destroyed: HP 0 / %.0f" % max_health, &"dummy")
		return

	_update_label("HIT -%.0f" % amount)
	if hurt_material != null:
		body_mesh.material_override = hurt_material
		get_tree().create_timer(0.18).timeout.connect(_restore_material, CONNECT_ONE_SHOT)
	_emit_notice("Dummy hit: HP %.0f / %.0f" % [current_health, max_health], &"dummy")


func _restore_material() -> void:
	if current_health > 0.0 and is_instance_valid(body_mesh):
		body_mesh.material_override = _default_material


func _update_label(state_text: String) -> void:
	label.text = "TEMP TEST DUMMY - DELETE LATER\nNOT AN ENEMY TEMPLATE\n%s\nHP %.0f / %.0f" % [
		state_text,
		current_health,
		max_health,
	]


func _emit_notice(message: String, category: StringName) -> void:
	if _event_bus != null:
		_event_bus.debug_test_notice.emit(message, category)

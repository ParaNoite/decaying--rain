class_name TemporaryWoodenDummy
extends StaticBody3D

# Temporary MVP test target only.
# Do not use this as an enemy template. Real enemies must follow the dedicated enemy system.

@export var destroyed_material: StandardMaterial3D
@export var hurt_material: StandardMaterial3D
@export var warning_material: StandardMaterial3D
@export_range(0.2, 20.0, 0.1) var attack_interval: float = 2.4
@export_range(0.1, 5.0, 0.05) var warning_duration: float = 0.75
@export_range(0.1, 5.0, 0.05) var strike_duration: float = 0.18
@export_range(0.1, 5.0, 0.05) var attack_range: float = 2.2
@export_range(0.0, 100.0, 1.0) var attack_damage: float = 15.0

@onready var label: Label3D = %StatusLabel
@onready var body_mesh: MeshInstance3D = %BodyMesh
@onready var health: HealthComponent = %HealthComponent

const STATE_IDLE: StringName = &"idle"
const STATE_WARNING: StringName = &"warning"
const STATE_STRIKE: StringName = &"strike"
const STATE_COOLDOWN: StringName = &"cooldown"

var attack_state: StringName = STATE_IDLE
var _state_time_remaining: float = 0.0
var _event_bus = null
var _default_material: Material


func _ready() -> void:
	add_to_group("enemy")
	_event_bus = get_node_or_null("/root/EventBus")
	health.died.connect(_on_health_died)
	_default_material = body_mesh.material_override
	_enter_state(STATE_IDLE)
	_emit_notice("Temporary wooden dummy ready: HP %.0f / %.0f" % [health.current_health, health.max_health], &"dummy")


func _physics_process(delta: float) -> void:
	if not health.is_alive():
		return

	_state_time_remaining = maxf(0.0, _state_time_remaining - delta)
	if _state_time_remaining > 0.0:
		return

	match attack_state:
		STATE_IDLE:
			_enter_state(STATE_WARNING)
		STATE_WARNING:
			_enter_state(STATE_STRIKE)
		STATE_STRIKE:
			_enter_state(STATE_COOLDOWN)
		STATE_COOLDOWN:
			_enter_state(STATE_IDLE)
		_:
			_enter_state(STATE_IDLE)


func receive_damage(data: DamageEventData) -> void:
	var resolver: Node = get_node_or_null("/root/DamageResolver")
	if resolver != null:
		resolver.call("resolve_damage", data, self)


func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var damage: DamageEventData = DamageEventData.new()
	damage.target_id = get_instance_id()
	damage.amount = amount
	damage.source_tags = [&"legacy_apply_damage"]
	damage.bypass_outgoing_modifiers = true
	receive_damage(damage)


func on_damage_resolved(result: DamageResolutionData) -> void:
	if not result.applied:
		return
	if result.final_amount <= 0.0:
		_update_label("HIT: stagger %.1f" % result.event.stagger)
		_emit_notice("Dummy shoved/staggered: HP %.0f / %.0f" % [health.current_health, health.max_health], &"dummy")
		return
	if not health.is_alive():
		return

	_update_label("HIT -%.0f" % result.final_amount)
	if hurt_material != null:
		body_mesh.material_override = hurt_material
		get_tree().create_timer(0.18).timeout.connect(_restore_material, CONNECT_ONE_SHOT)
	_emit_notice("Dummy hit: HP %.0f / %.0f" % [health.current_health, health.max_health], &"dummy")


func get_health_component() -> HealthComponent:
	return health


func _on_health_died() -> void:
	_update_label("DESTROYED")
	if destroyed_material != null:
		body_mesh.material_override = destroyed_material
	_emit_notice("Dummy destroyed: HP 0 / %.0f" % health.max_health, &"dummy")


func _enter_state(next_state: StringName) -> void:
	attack_state = next_state
	match attack_state:
		STATE_IDLE:
			_state_time_remaining = attack_interval
			_restore_material()
			_update_label("READY: next attack %.1fs" % attack_interval)
		STATE_WARNING:
			_state_time_remaining = warning_duration
			if warning_material != null:
				body_mesh.material_override = warning_material
			_update_label("WARNING: PARRY SOON")
			_emit_notice("Dummy flashing red: press Q before the strike", &"dummy")
		STATE_STRIKE:
			_state_time_remaining = strike_duration
			_update_label("STRIKE")
			_perform_melee_attack()
		STATE_COOLDOWN:
			_state_time_remaining = 0.35
			_restore_material()
			_update_label("RECOVER")
		_:
			_state_time_remaining = attack_interval


func _perform_melee_attack() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not (player is Node3D):
		_emit_notice("Dummy strike missed: no player", &"dummy")
		return

	var target: Node3D = player as Node3D
	var offset: Vector3 = target.global_position - global_position
	offset.y = 0.0
	if offset.length() > attack_range:
		_emit_notice("Dummy strike missed: out of range", &"dummy")
		return

	var hit_data: DamageEventData = DamageEventData.new()
	hit_data.attacker_id = get_instance_id()
	hit_data.target_id = target.get_instance_id()
	hit_data.amount = attack_damage
	hit_data.source_tags = [&"melee", &"temporary_test_dummy"]
	hit_data.stagger = 8.0
	hit_data.hit_position = target.global_position

	if target.has_method("receive_damage"):
		target.receive_damage(hit_data)
	_emit_notice("Dummy melee strike: %.0f damage" % attack_damage, &"dummy")


func _restore_material() -> void:
	if health.is_alive() and is_instance_valid(body_mesh):
		body_mesh.material_override = _default_material


func _update_label(state_text: String) -> void:
	label.text = "TEMP TEST DUMMY - DELETE LATER\nNOT AN ENEMY TEMPLATE\n%s\nHP %.0f / %.0f\nATK %.0f / RANGE %.1f" % [
		state_text,
		health.current_health,
		health.max_health,
		attack_damage,
		attack_range,
	]


func _emit_notice(message: String, category: StringName) -> void:
	if _event_bus != null:
		_event_bus.debug_test_notice.emit(message, category)

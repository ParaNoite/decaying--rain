class_name PlayerFirstPersonArms
extends Node3D

const ELBOW_LOWEST_ROTATION_X: float = 0.0698131701
const LIGHT_LEFT_SHOULDER_DEGREES: Vector3 = Vector3(18.0, -34.0, -28.0)
const LIGHT_LEFT_ELBOW_DEGREES: Vector3 = Vector3(-14.0, -82.0, 0.0)
const HEAVY_LIFT_FRACTION: float = 0.72
const SPRINT_POSE_BLEND_SPEED: float = 5.0

@export_range(0.0, 0.2, 0.005) var bob_amplitude: float = 0.028
@export_range(0.0, 20.0, 0.1) var bob_speed: float = 10.5

@onready var right_shoulder: Node3D = %RightShoulder
@onready var right_elbow: Node3D = %RightElbow
@onready var left_shoulder: Node3D = %LeftShoulder
@onready var left_elbow: Node3D = %LeftElbow
@onready var first_person_weapon_socket: Marker3D = %FirstPersonWeaponSocket
@onready var tool_proxy: MeshInstance3D = %ToolProxy

var _base_position: Vector3
var _base_rotation: Vector3
var _right_shoulder_base: Transform3D
var _right_elbow_base: Transform3D
var _left_shoulder_base: Transform3D
var _left_elbow_base: Transform3D
var _action_tween: Tween
var _left_guard_tween: Tween
var _light_combo_guard_active: bool = false
var _root_tween: Tween
var _sprinting: bool = false
var _bob_time: float = 0.0
var _root_motion_time_remaining: float = 0.0
var _watch_pose_active: bool = false
var current_action_timing: ActionTimingDefinition
var held_item_id: StringName = &""
var _held_item_proxy: MeshInstance3D
var _firearm: WeaponDefinition
var _firearm_visual: Node3D
var _firearm_aim: float = 0.0
var _firearm_action: StringName = &""
var _firearm_elapsed: float = 0.0
var _firearm_kick: float = 0.0
var _recoil_pulses: Array[Dictionary] = []
var _recoil_rotation: Vector2 = Vector2.ZERO
var _pose_without_recoil: Transform3D
var _recoil_pose_applied: bool = false
var _muzzle: MeshInstance3D


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	_right_shoulder_base = right_shoulder.transform
	_right_elbow_base = right_elbow.transform
	_left_shoulder_base = left_shoulder.transform
	_left_elbow_base = left_elbow.transform


func _process(delta: float) -> void:
	if _root_motion_time_remaining > 0.0:
		_root_motion_time_remaining = maxf(0.0, _root_motion_time_remaining - delta)
		return
	if _action_tween != null and _action_tween.is_running():
		return
	if _watch_pose_active:
		return
	if _firearm != null and held_item_id == &"":
		_update_firearm_pose(delta)
		return
	if _sprinting:
		_update_sprint_pose(delta)
	else:
		_update_relaxed_pose(delta)


func set_sprinting(active: bool) -> void:
	_sprinting = active


func set_held_item(item: ItemDefinition) -> void:
	var next_item_id: StringName = item.item_id if item != null else &""
	if held_item_id == next_item_id:
		return
	held_item_id = next_item_id
	if tool_proxy != null:
		tool_proxy.visible = item == null and _firearm == null
	if _firearm_visual != null:
		_firearm_visual.visible = item == null and _firearm != null
	if item == null:
		if _held_item_proxy != null:
			_held_item_proxy.visible = false
		return
	if _held_item_proxy == null:
		_held_item_proxy = MeshInstance3D.new()
		_held_item_proxy.name = "HeldItemProxy"
		_held_item_proxy.mesh = BoxMesh.new()
		_held_item_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		first_person_weapon_socket.add_child(_held_item_proxy)
	_held_item_proxy.visible = true
	var material := StandardMaterial3D.new()
	material.roughness = 0.82
	match item.visual_kind:
		ItemDefinition.VisualKind.BANDAGE:
			var bandage_mesh := BoxMesh.new()
			bandage_mesh.size = Vector3(0.26, 0.08, 0.15)
			_held_item_proxy.mesh = bandage_mesh
			_held_item_proxy.position = Vector3(-0.03, 0.04, -0.10)
			material.albedo_color = Color(0.84, 0.80, 0.68, 1.0)
		ItemDefinition.VisualKind.MEDKIT:
			var medkit_mesh := BoxMesh.new()
			medkit_mesh.size = Vector3(0.30, 0.18, 0.22)
			_held_item_proxy.mesh = medkit_mesh
			_held_item_proxy.position = Vector3(-0.02, 0.02, -0.13)
			material.albedo_color = Color(0.72, 0.10, 0.10, 1.0)
		ItemDefinition.VisualKind.FOOD:
			var food_mesh := CylinderMesh.new()
			food_mesh.top_radius = 0.10
			food_mesh.bottom_radius = 0.10
			food_mesh.height = 0.20
			_held_item_proxy.mesh = food_mesh
			_held_item_proxy.position = Vector3(-0.03, 0.04, -0.12)
			material.albedo_color = Color(0.72, 0.48, 0.16, 1.0)
		_:
			var default_mesh := BoxMesh.new()
			default_mesh.size = Vector3(0.18, 0.12, 0.22)
			_held_item_proxy.mesh = default_mesh
			_held_item_proxy.position = Vector3(-0.03, 0.04, -0.10)
			material.albedo_color = Color(0.42, 0.48, 0.44, 1.0)
	_held_item_proxy.material_override = material


func play_watch_raised(timing: ActionTimingDefinition) -> void:
	_begin_action(false, timing)
	_watch_pose_active = true
	_action_tween = _new_action_tween(Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_pose(
		_action_tween,
		Vector3(0.0, 0.0, 0.0),
		Vector3(8.0, 0.0, 0.0),
		Vector3(118.0, 18.0, 26.0),
		Vector3(92.0, -8.0, 0.0),
		timing.windup_seconds
	)
	_action_tween.chain().tween_interval(timing.release_seconds + timing.impact_seconds + timing.recovery_seconds)


func play_watch_lowered(timing: ActionTimingDefinition) -> void:
	if not _watch_pose_active:
		return
	_reset_action_tween()
	_action_tween = _new_action_tween(Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	_action_tween.tween_interval(timing.release_seconds + timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	_action_tween.chain().tween_callback(_clear_watch_pose)


func is_watch_pose_active() -> bool:
	return _watch_pose_active


func _clear_watch_pose() -> void:
	_watch_pose_active = false


func play_attack(combo_index: int, timing: ActionTimingDefinition, keep_left_guard: bool = false) -> void:
	var combo: int = clampi(combo_index, 1, 3)
	_begin_action(false, timing, keep_left_guard)
	match combo:
		1:
			_play_right_jab(timing, keep_left_guard)
		2:
			_play_right_hook(timing, keep_left_guard)
		3:
			_play_overhead_finish(timing, keep_left_guard)
		_:
			_play_right_jab(timing, keep_left_guard)


func release_light_combo_guard() -> void:
	if not _light_combo_guard_active:
		return
	_light_combo_guard_active = false
	_reset_left_guard_tween()
	_left_guard_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_left_guard_tween.tween_property(left_shoulder, "transform", _left_shoulder_base, 0.12)
	_left_guard_tween.tween_property(left_elbow, "transform", _left_elbow_base, 0.12)


func play_heavy_attack(timing: ActionTimingDefinition) -> void:
	_begin_action(false, timing)
	var lift_seconds: float = timing.windup_seconds * HEAVY_LIFT_FRACTION
	var overhead_hold_seconds: float = timing.windup_seconds - lift_seconds
	var overhead_right_shoulder: Vector3 = _right_shoulder_base.basis.get_euler() + _radians(Vector3(82, -26, -18))
	var overhead_right_elbow: Vector3 = _elbow_rotation(_right_elbow_base, Vector3(112, 8, 0))
	var overhead_left_shoulder: Vector3 = _left_shoulder_base.basis.get_euler() + _radians(Vector3(-8, 18, 10))
	var overhead_left_elbow: Vector3 = _elbow_rotation(_left_elbow_base, Vector3(62, -6, 0))
	_action_tween = create_tween()
	_action_tween.tween_property(right_shoulder, "rotation", overhead_right_shoulder, lift_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_action_tween.parallel().tween_property(right_elbow, "rotation", overhead_right_elbow, lift_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_action_tween.parallel().tween_property(left_shoulder, "rotation", overhead_left_shoulder, lift_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_action_tween.parallel().tween_property(left_elbow, "rotation", overhead_left_elbow, lift_seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_action_tween.chain().tween_interval(overhead_hold_seconds)
	_action_tween.chain().tween_property(right_shoulder, "rotation", _right_shoulder_base.basis.get_euler() + _radians(Vector3(-64, 34, 30)), timing.release_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(right_elbow, "rotation", _elbow_rotation(_right_elbow_base, Vector3(4, 0, 0)), timing.release_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(left_shoulder, "rotation", _left_shoulder_base.basis.get_euler() + _radians(Vector3(-18, -20, -12)), timing.release_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_action_tween.parallel().tween_property(left_elbow, "rotation", _elbow_rotation(_left_elbow_base, Vector3(70, 0, 0)), timing.release_seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_action_tween.chain().tween_property(right_shoulder, "transform", _right_shoulder_base, timing.recovery_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(right_elbow, "transform", _right_elbow_base, timing.recovery_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(left_shoulder, "transform", _left_shoulder_base, timing.recovery_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.parallel().tween_property(left_elbow, "transform", _left_elbow_base, timing.recovery_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func play_shove(timing: ActionTimingDefinition) -> void:
	_begin_action(true, timing)
	_start_root_motion(timing.total_seconds())
	_action_tween = _new_action_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_pose(_action_tween, Vector3(22, -30, -20), Vector3(96, 0, 0), Vector3(22, 30, 20), Vector3(96, 0, 0), timing.windup_seconds)
	_chain_pose(_action_tween, Vector3(-8, 6, -5), Vector3(-6, 0, 0), Vector3(-8, -6, 5), Vector3(-16, 0, 0), timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	_root_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, -0.015, 0.07), timing.windup_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position + Vector3(0.0, 0.015, -0.42), timing.release_seconds)
	_root_tween.chain().tween_interval(timing.impact_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position, timing.recovery_seconds)


func play_parry(timing: ActionTimingDefinition) -> void:
	_begin_action(false, timing)
	_action_tween = _new_action_tween(Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_pose(_action_tween, Vector3(42, 44, 28), Vector3(54, 10, 0), Vector3(42, -44, -28), Vector3(54, -10, 0), timing.windup_seconds)
	_action_tween.chain().tween_interval(timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)


func play_parry_success(timing: ActionTimingDefinition) -> void:
	current_action_timing = timing
	_reset_action_tween()
	_reset_root_tween()
	_start_root_motion(timing.total_seconds())
	_action_tween = _new_action_tween(Tween.TRANS_BACK, Tween.EASE_OUT)
	_action_tween.tween_interval(timing.windup_seconds)
	_chain_pose(_action_tween, Vector3(58, 58, 38), Vector3(76, 16, 0), Vector3(58, -58, -38), Vector3(76, -16, 0), timing.release_seconds)
	_chain_pose(_action_tween, Vector3(34, 34, 18), Vector3(56, 5, 0), Vector3(34, -34, -18), Vector3(56, -5, 0), timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	position = _base_position
	rotation = _base_rotation
	if is_zero_approx(timing.windup_seconds):
		position = _base_position + Vector3(-0.045, -0.02, 0.11)
		rotation = _base_rotation + _radians(Vector3(3.0, 0.0, -4.0))
	_root_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_root_tween.tween_interval(timing.windup_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position + Vector3(-0.08, -0.035, 0.17), timing.release_seconds)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation + _radians(Vector3(5.0, 0.0, -6.5)), timing.release_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position + Vector3(0.055, 0.025, 0.07), timing.impact_seconds)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation + _radians(Vector3(-3.0, 0.0, 4.5)), timing.impact_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position, timing.recovery_seconds)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation, timing.recovery_seconds)


func play_interact(timing: ActionTimingDefinition) -> void:
	_begin_action(false, timing)
	_action_tween = _new_action_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_pose(_action_tween, Vector3(-112, -28, -18), Vector3(24, 4, 0), Vector3(-4, -18, -8), Vector3(-14, 0, 0), timing.windup_seconds)
	_action_tween.tween_property(
		left_shoulder,
		"position",
		_left_shoulder_base.origin + Vector3(0.08, 0.07, -0.12),
		timing.windup_seconds
	)
	_action_tween.tween_property(
		right_shoulder,
		"position",
		_right_shoulder_base.origin + Vector3(0.0, -0.05, 0.10),
		timing.windup_seconds
	)
	_action_tween.chain().tween_interval(timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)


func play_charged_beam(timing: ActionTimingDefinition) -> void:
	_begin_action(true, timing)
	_start_root_motion(timing.total_seconds())
	_action_tween = _new_action_tween(Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_pose(_action_tween, Vector3(5, -22, -12), Vector3(82, 4, 0), Vector3(5, 22, 12), Vector3(82, -4, 0), timing.windup_seconds)
	_chain_pose(_action_tween, Vector3(-22, 5, -4), Vector3(3, 0, 0), Vector3(-22, -5, 4), Vector3(3, 0, 0), timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	_root_tween = create_tween().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, 0.02, 0.06), timing.windup_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_root_tween.chain().tween_property(self, "position", _base_position + Vector3(0.0, -0.02, 0.14), timing.release_seconds)
	_root_tween.chain().tween_interval(timing.impact_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position, timing.recovery_seconds)


func play_hurt(timing: ActionTimingDefinition) -> void:
	_begin_action(true, timing)
	_start_root_motion(timing.total_seconds())
	_action_tween = _new_action_tween(Tween.TRANS_BACK, Tween.EASE_OUT)
	_action_tween.tween_interval(timing.windup_seconds)
	_chain_pose(_action_tween, Vector3(22, -28, -20), Vector3(104, 12, 0), Vector3(22, 28, 20), Vector3(104, -12, 0), timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	_root_tween = create_tween().set_parallel(true)
	_root_tween.tween_interval(timing.windup_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position + Vector3(0.08, -0.05, 0.18), timing.release_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation + _radians(Vector3(3, 0, -5)), timing.release_seconds)
	_root_tween.chain().tween_interval(timing.impact_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position, timing.recovery_seconds)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation, timing.recovery_seconds)


func play_sprint_start(timing: ActionTimingDefinition) -> void:
	_begin_action(true, timing)
	_start_root_motion(timing.total_seconds())
	_action_tween = _new_action_tween(Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_pose(_action_tween, Vector3(16, -8, -8), Vector3(42, 0, 0), Vector3(4, 14, 10), Vector3(64, 0, 0), timing.windup_seconds)
	_action_tween.chain().tween_interval(timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	_root_tween = create_tween().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, 0.03, -0.06), timing.windup_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "rotation", _base_rotation + _radians(Vector3(-2, 0, 1)), timing.windup_seconds)
	_root_tween.chain().tween_interval(timing.release_seconds + timing.impact_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position, timing.recovery_seconds)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation, timing.recovery_seconds)


func play_jump(timing: ActionTimingDefinition) -> void:
	_begin_action(true, timing)
	_start_root_motion(timing.total_seconds())
	_action_tween = _new_action_tween(Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_pose(_action_tween, Vector3(-34, -18, -12), Vector3(8, 0, 0), Vector3(-34, 18, 12), Vector3(8, 0, 0), timing.windup_seconds)
	_action_tween.chain().tween_interval(timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	_root_tween = create_tween().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, -0.08, 0.08), timing.windup_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "rotation", _base_rotation + _radians(Vector3(4, 0, 0)), timing.windup_seconds)
	_root_tween.chain().tween_interval(timing.release_seconds + timing.impact_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position, timing.recovery_seconds)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation, timing.recovery_seconds)


func play_slide(timing: ActionTimingDefinition) -> void:
	_begin_action(true, timing)
	_start_root_motion(timing.total_seconds())
	_action_tween = _new_action_tween(Tween.TRANS_QUAD, Tween.EASE_OUT)
	_pose(_action_tween, Vector3(10, -30, -18), Vector3(88, 8, 0), Vector3(-20, 8, 10), Vector3(12, 0, 0), timing.windup_seconds)
	_action_tween.chain().tween_interval(timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_return(timing.recovery_seconds)
	_root_tween = create_tween().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, -0.12, -0.08), timing.windup_seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "rotation", _base_rotation + _radians(Vector3(-5, 0, 3)), timing.windup_seconds)
	_root_tween.chain().tween_interval(timing.release_seconds + timing.impact_seconds)
	_root_tween.chain().tween_property(self, "position", _base_position, timing.recovery_seconds)
	_root_tween.parallel().tween_property(self, "rotation", _base_rotation, timing.recovery_seconds)


func _play_right_jab(timing: ActionTimingDefinition, keep_left_guard: bool) -> void:
	_play_light_left_guard(timing, keep_left_guard)
	_action_tween = _new_action_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_pose_right(_action_tween, Vector3(14, -30, -12), Vector3(92, 8, 0), timing.windup_seconds)
	_chain_pose_right(_action_tween, Vector3(-12, -16, -5), Vector3(-4, 0, 0), timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_right_return(timing.recovery_seconds)


func _play_right_hook(timing: ActionTimingDefinition, keep_left_guard: bool) -> void:
	_play_light_left_guard(timing, keep_left_guard)
	_action_tween = _new_action_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_pose_right(_action_tween, Vector3(-8, -42, -30), Vector3(88, 4, 0), timing.windup_seconds)
	_chain_pose_right(_action_tween, Vector3(6, 58, 44), Vector3(38, 10, 0), timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_right_return(timing.recovery_seconds)


func _play_overhead_finish(timing: ActionTimingDefinition, keep_left_guard: bool) -> void:
	_play_light_left_guard(timing, keep_left_guard)
	_action_tween = _new_action_tween(Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	_pose_right(_action_tween, Vector3(78, -18, -12), Vector3(38, 6, 0), timing.windup_seconds)
	_chain_pose_right(_action_tween, Vector3(-42, 8, 16), Vector3(4, 0, 0), timing.release_seconds)
	_action_tween.chain().tween_interval(timing.impact_seconds)
	_queue_right_return(timing.recovery_seconds)


func _update_sprint_pose(delta: float) -> void:
	_bob_time += delta * bob_speed
	var phase: float = sin(_bob_time)
	var weight: float = 1.0 - exp(-SPRINT_POSE_BLEND_SPEED * delta)
	var bob_offset := Vector3(
		phase * bob_amplitude,
		absf(sin(_bob_time * 1.65)) * bob_amplitude * 1.15,
		sin(_bob_time * 0.5) * bob_amplitude * 0.30
	)
	position = position.lerp(_base_position + bob_offset, weight)
	rotation = rotation.lerp(_base_rotation + Vector3(0.0, 0.0, phase * deg_to_rad(1.8)), weight)
	_lerp_rotation(right_shoulder, _right_shoulder_base, Vector3(-30.0 + phase * 10.0, -8.0, -12.0), weight)
	_lerp_elbow_rotation(right_elbow, _right_elbow_base, Vector3(12.0 + phase * 6.0, 0.0, 0.0), weight)
	_lerp_rotation(left_shoulder, _left_shoulder_base, Vector3(-30.0 - phase * 10.0, 8.0, 12.0), weight)
	_lerp_elbow_rotation(left_elbow, _left_elbow_base, Vector3(12.0 - phase * 6.0, 0.0, 0.0), weight)


func _update_relaxed_pose(delta: float) -> void:
	_bob_time += delta * 1.6
	var breath: float = sin(_bob_time) * 1.2
	var weight: float = minf(1.0, delta * 9.0)
	position = position.lerp(_base_position + Vector3(0.0, breath * 0.0015, 0.0), weight)
	rotation = rotation.lerp(_base_rotation, weight)
	_lerp_rotation(right_shoulder, _right_shoulder_base, Vector3(breath, -2.0, -2.0), weight)
	_lerp_elbow_rotation(right_elbow, _right_elbow_base, Vector3(8.0 + breath, 0.0, 0.0), weight)
	if _light_combo_guard_active:
		return
	_lerp_rotation(left_shoulder, _left_shoulder_base, Vector3(-breath, 2.0, 2.0), weight)
	_lerp_elbow_rotation(left_elbow, _left_elbow_base, Vector3(18.0 - breath, 0.0, 0.0), weight)


func _begin_action(reset_root: bool = false, timing: ActionTimingDefinition = null, preserve_light_guard: bool = false) -> void:
	# 新动作接管姿态前移除射击叠层，避免动作结束后重播残留冲击。
	reset_firearm_recoil()
	_watch_pose_active = false
	current_action_timing = timing
	_reset_action_tween()
	if not preserve_light_guard:
		release_light_combo_guard()
		_reset_left_guard_tween()
	if reset_root:
		_reset_root_tween()
	_reset_right_pose()
	if not preserve_light_guard:
		left_shoulder.transform = _left_shoulder_base
		left_elbow.transform = _left_elbow_base


func _new_action_tween(trans: Tween.TransitionType, ease_type: Tween.EaseType) -> Tween:
	return create_tween().set_parallel(true).set_trans(trans).set_ease(ease_type)


func _pose(
	tween: Tween,
	right_shoulder_degrees: Vector3,
	right_elbow_degrees: Vector3,
	left_shoulder_degrees: Vector3,
	left_elbow_degrees: Vector3,
	duration: float
) -> void:
	tween.tween_property(right_shoulder, "rotation", _right_shoulder_base.basis.get_euler() + _radians(right_shoulder_degrees), duration)
	tween.tween_property(right_elbow, "rotation", _elbow_rotation(_right_elbow_base, right_elbow_degrees), duration)
	tween.tween_property(left_shoulder, "rotation", _left_shoulder_base.basis.get_euler() + _radians(left_shoulder_degrees), duration)
	tween.tween_property(left_elbow, "rotation", _elbow_rotation(_left_elbow_base, left_elbow_degrees), duration)


func _pose_right(
	tween: Tween,
	shoulder_degrees: Vector3,
	elbow_degrees: Vector3,
	duration: float
) -> void:
	tween.tween_property(right_shoulder, "rotation", _right_shoulder_base.basis.get_euler() + _radians(shoulder_degrees), duration)
	tween.tween_property(right_elbow, "rotation", _elbow_rotation(_right_elbow_base, elbow_degrees), duration)


func _chain_pose(
	tween: Tween,
	right_shoulder_degrees: Vector3,
	right_elbow_degrees: Vector3,
	left_shoulder_degrees: Vector3,
	left_elbow_degrees: Vector3,
	duration: float
) -> void:
	tween.chain().tween_property(right_shoulder, "rotation", _right_shoulder_base.basis.get_euler() + _radians(right_shoulder_degrees), duration)
	tween.parallel().tween_property(right_elbow, "rotation", _elbow_rotation(_right_elbow_base, right_elbow_degrees), duration)
	tween.parallel().tween_property(left_shoulder, "rotation", _left_shoulder_base.basis.get_euler() + _radians(left_shoulder_degrees), duration)
	tween.parallel().tween_property(left_elbow, "rotation", _elbow_rotation(_left_elbow_base, left_elbow_degrees), duration)


func _chain_pose_right(
	tween: Tween,
	shoulder_degrees: Vector3,
	elbow_degrees: Vector3,
	duration: float
) -> void:
	tween.chain().tween_property(right_shoulder, "rotation", _right_shoulder_base.basis.get_euler() + _radians(shoulder_degrees), duration)
	tween.parallel().tween_property(right_elbow, "rotation", _elbow_rotation(_right_elbow_base, elbow_degrees), duration)


func _play_light_left_guard(timing: ActionTimingDefinition, keep_guard: bool) -> void:
	if _light_combo_guard_active:
		return
	_light_combo_guard_active = true
	_reset_left_guard_tween()
	_left_guard_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_left_guard_tween.tween_property(
		left_shoulder,
		"rotation",
		_left_shoulder_base.basis.get_euler() + _radians(LIGHT_LEFT_SHOULDER_DEGREES),
		timing.windup_seconds
	)
	_left_guard_tween.parallel().tween_property(
		left_elbow,
		"rotation",
		_elbow_rotation(_left_elbow_base, LIGHT_LEFT_ELBOW_DEGREES),
		timing.windup_seconds
	)
	if not keep_guard:
		_left_guard_tween.chain().tween_interval(timing.release_seconds + timing.impact_seconds)
		_left_guard_tween.chain().tween_property(left_shoulder, "transform", _left_shoulder_base, timing.recovery_seconds)
		_left_guard_tween.parallel().tween_property(left_elbow, "transform", _left_elbow_base, timing.recovery_seconds)
		_light_combo_guard_active = false


func _queue_return(duration: float) -> void:
	_action_tween.chain().tween_property(right_shoulder, "transform", _right_shoulder_base, duration)
	_action_tween.parallel().tween_property(right_elbow, "transform", _right_elbow_base, duration)
	_action_tween.parallel().tween_property(left_shoulder, "transform", _left_shoulder_base, duration)
	_action_tween.parallel().tween_property(left_elbow, "transform", _left_elbow_base, duration)


func _queue_right_return(duration: float) -> void:
	_action_tween.chain().tween_property(right_shoulder, "transform", _right_shoulder_base, duration)
	_action_tween.parallel().tween_property(right_elbow, "transform", _right_elbow_base, duration)


func _lerp_rotation(node: Node3D, base: Transform3D, degrees_offset: Vector3, weight: float) -> void:
	var target: Vector3 = base.basis.get_euler() + _radians(degrees_offset)
	node.rotation = node.rotation.lerp(target, clampf(weight, 0.0, 1.0))


func _lerp_elbow_rotation(node: Node3D, base: Transform3D, degrees_offset: Vector3, weight: float) -> void:
	var target: Vector3 = _elbow_rotation(base, degrees_offset)
	node.rotation = node.rotation.lerp(target, clampf(weight, 0.0, 1.0))


func _elbow_rotation(base: Transform3D, degrees_offset: Vector3) -> Vector3:
	var target: Vector3 = base.basis.get_euler() + _radians(degrees_offset)
	target.x = maxf(target.x, ELBOW_LOWEST_ROTATION_X)
	return target


func _reset_action_tween() -> void:
	if _action_tween != null:
		_action_tween.kill()


func _reset_left_guard_tween() -> void:
	if _left_guard_tween != null:
		_left_guard_tween.kill()


func _reset_root_tween() -> void:
	if _root_tween != null:
		_root_tween.kill()


func _start_root_motion(duration: float) -> void:
	_root_motion_time_remaining = maxf(_root_motion_time_remaining, duration)


func _reset_pose() -> void:
	_reset_right_pose()
	left_shoulder.transform = _left_shoulder_base
	left_elbow.transform = _left_elbow_base


func _reset_right_pose() -> void:
	right_shoulder.transform = _right_shoulder_base
	right_elbow.transform = _right_elbow_base
	rotation = _base_rotation


func _radians(degrees: Vector3) -> Vector3:
	return Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))


func set_firearm(weapon: WeaponDefinition, aim: float) -> void:
	_firearm_aim = aim
	if _firearm == weapon:
		return
	reset_firearm_recoil()
	_firearm = weapon
	cancel_firearm_action()
	_reset_action_tween()
	_reset_left_guard_tween()
	_reset_root_tween()
	if _firearm_visual != null:
		_firearm_visual.queue_free()
		_firearm_visual = null
	tool_proxy.visible = weapon == null and held_item_id == &""
	if weapon == null:
		return
	_firearm_visual = Node3D.new()
	_firearm_visual.name = "FirearmVisual"
	_firearm_visual.rotation_degrees.x = -65.0
	first_person_weapon_socket.add_child(_firearm_visual)
	_firearm_visual.visible = held_item_id == &""
	var length: float = 0.28 if weapon.weapon_id == &"pistol" else 0.60
	if weapon.weapon_id == &"shotgun":
		length = 0.78
	var metal: Color = Color(0.085, 0.11, 0.13)
	_add_gun_part(Vector3(0.095, 0.09, length), Vector3(0, 0.09, -length * 0.35), metal)
	_add_gun_part(Vector3(0.07, 0.15, 0.085), Vector3(0, -0.025, 0.015), Color(0.17, 0.20, 0.19))
	_add_gun_part(Vector3(0.045, 0.045, 0.16), Vector3(0, 0.10, -length * 0.85), metal)
	_add_gun_part(Vector3(0.018, 0.025, 0.025), Vector3(0, 0.15, -length * 0.7), Color(0.8, 0.9, 0.65))
	for side: float in [-1.0, 1.0]:
		_add_gun_part(Vector3(0.016, 0.025, 0.025), Vector3(side * 0.03, 0.15, 0.03), metal)
	if weapon.weapon_id != &"pistol":
		_add_gun_part(Vector3(0.075, 0.20, 0.10), Vector3(0, -0.04, -0.16), metal)
		_add_gun_part(Vector3(0.08, 0.09, 0.18), Vector3(0, 0.05, 0.15), metal)
	_muzzle = _add_gun_part(Vector3(0.07, 0.07, 0.035), Vector3(0, 0.10, -length * 0.85 - 0.10), Color(1.0, 0.7, 0.2))
	var flash_material: StandardMaterial3D = _muzzle.material_override as StandardMaterial3D
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_muzzle.visible = false


func _add_gun_part(size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = offset
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_firearm_visual.add_child(part)
	return part


func play_firearm_fire(timing: ActionTimingDefinition) -> void:
	current_action_timing = timing
	_firearm_elapsed = 0.0
	_firearm_action = &"fire"


func play_firearm_reload(timing: ActionTimingDefinition) -> void:
	current_action_timing = timing
	_firearm_elapsed = 0.0
	_firearm_action = &"reload"


func firearm_impact(recoil_multiplier: float = 1.0, horizontal_direction: float = 1.0) -> void:
	if _firearm != null:
		_recoil_pulses.append({"elapsed": 0.0, "timing": _firearm.primary_timing,
			"strength": maxf(0.0, recoil_multiplier), "side": signf(horizontal_direction)})


func reset_firearm_recoil() -> void:
	if _recoil_pose_applied:
		transform = _pose_without_recoil
	_recoil_pose_applied = false
	_recoil_pulses.clear()
	_firearm_kick = 0.0
	_recoil_rotation = Vector2.ZERO


func _advance_firearm_recoil(delta: float) -> void:
	var strength: float = 0.0
	var side: float = 0.0
	for index: int in range(_recoil_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = _recoil_pulses[index]
		var timing: ActionTimingDefinition = pulse["timing"]
		pulse["elapsed"] += delta
		var elapsed: float = pulse["elapsed"]
		var duration: float = timing.impact_seconds + timing.recovery_seconds
		if elapsed >= duration:
			_recoil_pulses.remove_at(index)
			continue
		var envelope: float
		if elapsed < timing.impact_seconds:
			envelope = smoothstep(0.0, timing.impact_seconds, elapsed)
		else:
			envelope = 1.0 - smoothstep(0.0, maxf(0.000001, timing.recovery_seconds), elapsed - timing.impact_seconds)
		strength += envelope * float(pulse["strength"])
		side += envelope * float(pulse["strength"]) * float(pulse["side"])
	var limit: float = maxf(0.0, _firearm.viewmodel_recoil_limit)
	var ads_scale: float = lerpf(1.0, _firearm.viewmodel_ads_multiplier, _firearm_aim)
	_firearm_kick = minf(strength, limit) * _firearm.viewmodel_kick * ads_scale
	_recoil_rotation = Vector2(minf(strength, limit) * _firearm.viewmodel_pitch_degrees, clampf(side, -limit, limit) * _firearm.viewmodel_yaw_degrees) * ads_scale


func cancel_firearm_action() -> void:
	_firearm_action = &""
	_firearm_elapsed = 0.0


func _update_firearm_pose(delta: float) -> void:
	if _recoil_pose_applied:
		transform = _pose_without_recoil
		_recoil_pose_applied = false
	_advance_firearm_recoil(delta)
	_firearm_elapsed += delta
	var reload_weight: float = 0.0
	if _firearm_action == &"reload" and current_action_timing != null:
		var t: ActionTimingDefinition = current_action_timing
		if _firearm_elapsed < t.windup_seconds:
			reload_weight = _firearm_elapsed / maxf(t.windup_seconds, 0.001)
		elif _firearm_elapsed < t.impact_end_seconds():
			reload_weight = 1.0
		else:
			reload_weight = 1.0 - clampf((_firearm_elapsed - t.impact_end_seconds()) / maxf(t.recovery_seconds, 0.001), 0.0, 1.0)
	var weight: float = 1.0 - exp(-24.0 * delta)
	# 整条肩肘手链共同回弹，枪始终留在手部插槽。
	position = position.lerp(_base_position + Vector3(-0.17 * _firearm_aim, -0.10 + 0.12 * _firearm_aim - 0.09 * reload_weight, -0.12 * (1.0 - _firearm_aim)), weight)
	rotation = _base_rotation
	_lerp_rotation(right_shoulder, _right_shoulder_base, Vector3(-8.0, 4.0, -6.0 - 18.0 * reload_weight), weight)
	_lerp_elbow_rotation(right_elbow, _right_elbow_base, Vector3(70.0, -4.0, 0.0), weight)
	_lerp_rotation(left_shoulder, _left_shoulder_base, Vector3(-12.0, -30.0, 12.0), weight)
	_lerp_elbow_rotation(left_elbow, _left_elbow_base, Vector3(30.0 - 14.0 * reload_weight, 20.0, 0.0), weight)
	# 调整整条持枪手臂，使机械瞄具与相机视线一致；武器不脱离手掌。
	if _firearm_visual != null and get_parent() is Camera3D:
		var camera: Camera3D = get_parent() as Camera3D
		var chain: Basis = right_shoulder.global_basis.inverse() * _firearm_visual.global_basis
		var desired: Basis = global_basis.orthonormalized().inverse() * camera.global_basis.orthonormalized() * chain.orthonormalized().inverse()
		right_shoulder.quaternion = right_shoulder.quaternion.slerp(desired.get_rotation_quaternion(), 1.0 - reload_weight)
		var sight: Vector3 = camera.to_local(_firearm_visual.to_global(Vector3(0, 0.15, 0.03)))
		position.x -= sight.x * _firearm_aim
		position.y -= (sight.y + 0.003) * _firearm_aim
		position.z += (-0.48 - sight.z) * _firearm_aim
	_pose_without_recoil = transform
	position += Vector3(0.0, _firearm_kick * 0.12, _firearm_kick)
	rotation += Vector3(deg_to_rad(_recoil_rotation.x), deg_to_rad(_recoil_rotation.y), 0.0)
	_recoil_pose_applied = true
	if _muzzle != null:
		_muzzle.visible = _firearm_action == &"fire" and current_action_timing != null and current_action_timing.phase_at(_firearm_elapsed) == ActionTimingDefinition.Phase.IMPACT

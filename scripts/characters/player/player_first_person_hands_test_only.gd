class_name PlayerFirstPersonHandsTestOnly
extends Node3D

# Temporary first-person hand proxies for MVP feel testing only.
# Delete this when the real animation/weapon viewmodel system exists.

@export_range(0.0, 0.2, 0.005) var bob_amplitude: float = 0.036
@export_range(0.0, 20.0, 0.1) var bob_speed: float = 11.5

@onready var right_hand: Node3D = %RightHandProxy
@onready var left_hand: Node3D = %LeftHandProxy
@onready var tool_proxy: Node3D = %ToolProxy

var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _right_base: Transform3D
var _left_base: Transform3D
var _tool_base: Transform3D
var _action_tween: Tween
var _root_tween: Tween
var _sprinting: bool = false
var _bob_time: float = 0.0
var _root_motion_time_remaining: float = 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation
	_right_base = right_hand.transform
	_left_base = left_hand.transform
	_tool_base = tool_proxy.transform


func _process(delta: float) -> void:
	if _root_motion_time_remaining > 0.0:
		_root_motion_time_remaining = maxf(0.0, _root_motion_time_remaining - delta)
		return

	if not _sprinting:
		position = position.lerp(_base_position, minf(1.0, delta * 8.0))
		rotation = rotation.lerp(_base_rotation, minf(1.0, delta * 8.0))
		return

	_bob_time += delta * bob_speed
	var bob_offset: Vector3 = Vector3(
		sin(_bob_time) * bob_amplitude,
		abs(sin(_bob_time * 1.65)) * bob_amplitude * 1.25,
		sin(_bob_time * 0.5) * bob_amplitude * 0.35
	)
	position = _base_position + bob_offset
	rotation.z = _base_rotation.z + sin(_bob_time) * deg_to_rad(1.5)


func set_sprinting(active: bool) -> void:
	_sprinting = active


func play_attack(combo_index: int) -> void:
	_reset_action_tween()
	_reset_pose()

	var clamped_combo: int = clampi(combo_index, 1, 3)
	var reach: float = 0.58 + float(clamped_combo) * 0.08
	var windup_side: float = 0.20 if clamped_combo % 2 == 1 else -0.20
	var strike_side: float = -0.11 if clamped_combo % 2 == 1 else 0.11
	var right_attack_rotation: Vector3 = _right_base.basis.get_euler() + Vector3(
		deg_to_rad(-42.0),
		deg_to_rad(28.0 * float(clamped_combo)),
		deg_to_rad(-24.0 * float(clamped_combo))
	)
	var left_brace_rotation: Vector3 = _left_base.basis.get_euler() + Vector3(
		deg_to_rad(-12.0),
		deg_to_rad(-16.0),
		deg_to_rad(10.0)
	)

	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(windup_side, 0.09, 0.16), 0.08)
	_action_tween.tween_property(right_hand, "rotation", _right_base.basis.get_euler() + Vector3(deg_to_rad(18.0), deg_to_rad(-22.0 * windup_side), deg_to_rad(28.0 * windup_side)), 0.08)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-windup_side * 0.45, -0.02, -0.12), 0.08)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(windup_side * 0.55, 0.06, 0.08), 0.08)
	_action_tween.tween_property(tool_proxy, "rotation", _tool_base.basis.get_euler() + Vector3(deg_to_rad(28.0), deg_to_rad(22.0 * windup_side), deg_to_rad(-18.0 * windup_side)), 0.08)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(strike_side, -0.08, -reach), 0.14)
	_action_tween.tween_property(right_hand, "rotation", right_attack_rotation, 0.14)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-strike_side * 0.6, -0.03, -0.30), 0.14)
	_action_tween.tween_property(left_hand, "rotation", left_brace_rotation, 0.14)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(strike_side * 0.8, -0.02, -reach * 0.92), 0.14)
	_action_tween.tween_property(tool_proxy, "rotation", _tool_base.basis.get_euler() + Vector3(deg_to_rad(-68.0), deg_to_rad(22.0 * strike_side), deg_to_rad(-36.0 * float(clamped_combo))), 0.14)
	_action_tween.chain().tween_interval(0.04)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "transform", _right_base, 0.22)
	_action_tween.tween_property(left_hand, "transform", _left_base, 0.22)
	_action_tween.tween_property(tool_proxy, "transform", _tool_base, 0.22)


func play_heavy_attack() -> void:
	_reset_action_tween()
	_reset_pose()

	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(0.16, 0.12, 0.22), 0.16)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-0.08, 0.04, -0.22), 0.16)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(0.10, 0.12, 0.12), 0.16)
	_action_tween.tween_property(tool_proxy, "rotation", _tool_base.basis.get_euler() + Vector3(deg_to_rad(42.0), deg_to_rad(18.0), deg_to_rad(-28.0)), 0.16)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(-0.12, -0.10, -0.76), 0.18)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(0.04, -0.04, -0.34), 0.18)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(-0.08, -0.06, -0.72), 0.18)
	_action_tween.tween_property(tool_proxy, "rotation", _tool_base.basis.get_euler() + Vector3(deg_to_rad(-82.0), deg_to_rad(-12.0), deg_to_rad(34.0)), 0.18)
	_action_tween.chain().tween_interval(0.06)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "transform", _right_base, 0.26)
	_action_tween.tween_property(left_hand, "transform", _left_base, 0.26)
	_action_tween.tween_property(tool_proxy, "transform", _tool_base, 0.26)


func play_shove() -> void:
	_reset_action_tween()
	_reset_pose()

	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(0.09, 0.08, 0.18), 0.07)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-0.09, 0.08, 0.18), 0.07)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(0.0, 0.10, 0.08), 0.07)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(0.12, -0.02, -0.76), 0.15)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-0.12, -0.02, -0.76), 0.15)
	_action_tween.tween_property(right_hand, "rotation", _right_base.basis.get_euler() + Vector3(deg_to_rad(-32.0), deg_to_rad(8.0), deg_to_rad(-10.0)), 0.15)
	_action_tween.tween_property(left_hand, "rotation", _left_base.basis.get_euler() + Vector3(deg_to_rad(-32.0), deg_to_rad(-8.0), deg_to_rad(10.0)), 0.15)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(0.0, 0.06, -0.46), 0.15)
	_action_tween.chain().tween_interval(0.06)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "transform", _right_base, 0.24)
	_action_tween.tween_property(left_hand, "transform", _left_base, 0.24)
	_action_tween.tween_property(tool_proxy, "transform", _tool_base, 0.24)


func play_parry(duration: float) -> void:
	_reset_action_tween()
	_reset_pose()

	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(right_hand, "position", Vector3(0.18, -0.12, -0.46), 0.08)
	_action_tween.tween_property(left_hand, "position", Vector3(-0.18, -0.12, -0.46), 0.08)
	_action_tween.tween_property(tool_proxy, "position", Vector3(0.0, -0.08, -0.42), 0.08)
	_action_tween.tween_property(tool_proxy, "rotation", Vector3(deg_to_rad(78.0), 0.0, 0.0), 0.08)
	_action_tween.chain().tween_interval(maxf(0.05, duration))
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "transform", _right_base, 0.14)
	_action_tween.tween_property(left_hand, "transform", _left_base, 0.14)
	_action_tween.tween_property(tool_proxy, "transform", _tool_base, 0.14)


func play_interact() -> void:
	_reset_action_tween()
	_reset_pose()

	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(-0.12, 0.03, -0.68), 0.16)
	_action_tween.tween_property(right_hand, "rotation", _right_base.basis.get_euler() + Vector3(deg_to_rad(-30.0), deg_to_rad(-18.0), deg_to_rad(8.0)), 0.16)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-0.04, -0.03, -0.20), 0.16)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(-0.04, 0.02, -0.28), 0.16)
	_action_tween.chain().tween_interval(0.08)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "transform", _right_base, 0.22)
	_action_tween.tween_property(left_hand, "transform", _left_base, 0.22)
	_action_tween.tween_property(tool_proxy, "transform", _tool_base, 0.22)


func play_charged_beam(windup_seconds: float) -> void:
	_reset_action_tween()
	_reset_root_tween()
	_reset_pose()
	_start_root_motion(maxf(0.26, windup_seconds + 0.18))

	var charge_time: float = maxf(0.05, windup_seconds)
	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(-0.02, 0.10, -0.26), charge_time)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(0.02, 0.10, -0.26), charge_time)
	_action_tween.tween_property(right_hand, "rotation", _right_base.basis.get_euler() + Vector3(deg_to_rad(-18.0), deg_to_rad(-10.0), deg_to_rad(-16.0)), charge_time)
	_action_tween.tween_property(left_hand, "rotation", _left_base.basis.get_euler() + Vector3(deg_to_rad(-18.0), deg_to_rad(10.0), deg_to_rad(16.0)), charge_time)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(0.0, 0.10, -0.34), charge_time)
	_action_tween.tween_property(tool_proxy, "rotation", _tool_base.basis.get_euler() + Vector3(deg_to_rad(-18.0), 0.0, 0.0), charge_time)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(0.16, -0.02, -0.82), 0.10)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-0.16, -0.02, -0.82), 0.10)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(0.0, -0.02, -0.92), 0.10)
	_action_tween.tween_property(tool_proxy, "rotation", _tool_base.basis.get_euler() + Vector3(deg_to_rad(-84.0), 0.0, 0.0), 0.10)
	_action_tween.chain().tween_interval(0.04)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "transform", _right_base, 0.18)
	_action_tween.tween_property(left_hand, "transform", _left_base, 0.18)
	_action_tween.tween_property(tool_proxy, "transform", _tool_base, 0.18)

	_root_tween = create_tween().set_parallel(true)
	_root_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, 0.02, 0.08), charge_time)
	_root_tween.chain().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, -0.02, 0.18), 0.08)
	_root_tween.chain().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position, 0.18)


func play_hurt() -> void:
	_reset_action_tween()
	_reset_root_tween()
	_reset_pose()
	_start_root_motion(0.28)

	_action_tween = create_tween().set_parallel(true)
	_action_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_action_tween.tween_property(right_hand, "position", _right_base.origin + Vector3(0.10, -0.09, 0.18), 0.07)
	_action_tween.tween_property(left_hand, "position", _left_base.origin + Vector3(-0.10, -0.09, 0.18), 0.07)
	_action_tween.tween_property(tool_proxy, "position", _tool_base.origin + Vector3(0.0, -0.08, 0.14), 0.07)
	_action_tween.chain().set_parallel(true)
	_action_tween.tween_property(right_hand, "transform", _right_base, 0.21)
	_action_tween.tween_property(left_hand, "transform", _left_base, 0.21)
	_action_tween.tween_property(tool_proxy, "transform", _tool_base, 0.21)

	_root_tween = create_tween().set_parallel(true)
	_root_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.08, -0.04, 0.20), 0.07)
	_root_tween.tween_property(self, "rotation", _base_rotation + Vector3(deg_to_rad(2.0), 0.0, deg_to_rad(-3.0)), 0.07)
	_root_tween.chain().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position, 0.21)
	_root_tween.tween_property(self, "rotation", _base_rotation, 0.21)


func play_sprint_start() -> void:
	_reset_root_tween()
	_start_root_motion(0.22)

	_root_tween = create_tween().set_parallel(true)
	_root_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, 0.035, -0.08), 0.08)
	_root_tween.tween_property(self, "rotation", _base_rotation + Vector3(deg_to_rad(-1.5), 0.0, 0.0), 0.08)
	_root_tween.chain().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position, 0.14)
	_root_tween.tween_property(self, "rotation", _base_rotation, 0.14)


func play_jump() -> void:
	_reset_root_tween()
	_start_root_motion(0.24)

	_root_tween = create_tween().set_parallel(true)
	_root_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, -0.08, 0.10), 0.08)
	_root_tween.tween_property(self, "rotation", _base_rotation + Vector3(deg_to_rad(3.0), 0.0, 0.0), 0.08)
	_root_tween.chain().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position, 0.16)
	_root_tween.tween_property(self, "rotation", _base_rotation, 0.16)


func play_slide() -> void:
	_reset_root_tween()
	_start_root_motion(0.36)

	_root_tween = create_tween().set_parallel(true)
	_root_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_root_tween.tween_property(self, "position", _base_position + Vector3(0.0, -0.11, -0.10), 0.10)
	_root_tween.tween_property(self, "rotation", _base_rotation + Vector3(deg_to_rad(-4.0), 0.0, deg_to_rad(2.0)), 0.10)
	_root_tween.chain().tween_interval(0.08)
	_root_tween.chain().set_parallel(true)
	_root_tween.tween_property(self, "position", _base_position, 0.18)
	_root_tween.tween_property(self, "rotation", _base_rotation, 0.18)


func _reset_action_tween() -> void:
	if _action_tween != null:
		_action_tween.kill()


func _reset_root_tween() -> void:
	if _root_tween != null:
		_root_tween.kill()


func _start_root_motion(duration: float) -> void:
	_root_motion_time_remaining = maxf(_root_motion_time_remaining, duration)


func _reset_pose() -> void:
	right_hand.transform = _right_base
	left_hand.transform = _left_base
	tool_proxy.transform = _tool_base
	rotation = _base_rotation

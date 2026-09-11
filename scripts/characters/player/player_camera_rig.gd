class_name PlayerCameraRig
extends Node

@export var head_path: NodePath = ^"../Head"
@export var camera_path: NodePath = ^"../Head/Camera3D"
@export var movement_definition: PlayerMovementDefinition
@export_range(40.0, 110.0, 1.0) var base_fov: float = 75.0
@export_range(40.0, 120.0, 1.0) var sprint_fov: float = 88.0
@export_range(1.0, 30.0, 1.0) var fov_lerp_speed: float = 12.0

@onready var head: Node3D = get_node(head_path)
@onready var camera: Camera3D = get_node_or_null(camera_path) as Camera3D
var firearm: WeaponDefinition
var aim_fraction: float = 0.0
var recoil_offset: Vector2 = Vector2.ZERO
var recoil_target: Vector2 = Vector2.ZERO
var _recoil_weapon: WeaponDefinition
var recoil_delay: float = 0.0
var recoil_recovery_multiplier: float = 1.0


func _ready() -> void:
	if camera != null:
		camera.fov = base_fov


func capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func recapture_from_click(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		capture_mouse()
		return true
	return false


func handle_look(event: InputEvent, body: Node3D) -> bool:
	if not (event is InputEventMouseMotion):
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false

	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	var sensitivity: float = 0.0025
	var pitch_limit: float = deg_to_rad(80.0)
	if movement_definition != null:
		sensitivity = movement_definition.mouse_sensitivity
		pitch_limit = deg_to_rad(movement_definition.pitch_limit_degrees)
	if camera != null:
		sensitivity *= camera.fov / base_fov
	var look: Vector2 = compensate_recoil(Vector2(-mouse_motion.relative.y, -mouse_motion.relative.x) * sensitivity)
	body.rotate_y(look.y)
	head.rotate_x(look.x)
	head.rotation.x = clampf(head.rotation.x, -pitch_limit, pitch_limit)
	_apply_recoil()
	return true


func update_motion_feedback(sprinting: bool, delta: float) -> void:
	if camera == null:
		return

	var target_fov: float = sprint_fov if sprinting else base_fov
	if firearm != null:
		target_fov = lerpf(target_fov, firearm.ads_fov, aim_fraction)
	var blend: float = minf(1.0, fov_lerp_speed * delta)
	camera.fov = lerpf(camera.fov, target_fov, blend)


func add_firearm_recoil(weapon: WeaponDefinition, recoil: Vector2) -> void:
	firearm = weapon
	_recoil_weapon = weapon
	recoil_target += Vector2(deg_to_rad(recoil.x), deg_to_rad(recoil.y))
	for axis: int in 2:
		var limit: float = deg_to_rad(absf(weapon.recoil_limit_degrees[axis]))
		recoil_target[axis] = clampf(recoil_target[axis], -limit, limit)
	recoil_delay = weapon.recoil_reset_seconds


func _process(delta: float) -> void:
	advance_recoil(delta)


func set_firearm(weapon: WeaponDefinition) -> void:
	if firearm != weapon:
		recoil_target = recoil_offset
		recoil_delay = 0.0
	firearm = weapon


func reset_recoil() -> void:
	recoil_offset = Vector2.ZERO
	recoil_target = Vector2.ZERO
	recoil_delay = 0.0
	_recoil_weapon = null
	_apply_recoil()


func compensate_recoil(look: Vector2) -> Vector2:
	for axis: int in 2:
		var current: float = recoil_offset[axis]
		var target: float = recoil_target[axis]
		if look[axis] * current < 0.0 or look[axis] * target < 0.0:
			var direction: float = -signf(look[axis])
			var amount: float = minf(absf(look[axis]), maxf(current * direction, target * direction))
			var visible_amount: float = minf(amount, maxf(0.0, current * direction))
			recoil_offset[axis] -= visible_amount * direction
			if target * direction > 0.0:
				recoil_target[axis] = direction * maxf(0.0, absf(target) - amount)
			# 未显示的冲击也消耗输入，避免下一帧再次上抬。
			look[axis] += direction * amount
	return look


func advance_recoil(delta: float) -> void:
	if _recoil_weapon == null:
		return
	# 小步积分让跨越回正延迟的帧保持一致；响应为无过冲指数阻尼。
	var remaining: float = maxf(0.0, delta)
	while remaining > 0.000001:
		var step: float = minf(remaining, 1.0 / 480.0)
		recoil_delay = maxf(0.0, recoil_delay - step)
		if recoil_delay <= 0.0:
			recoil_target = recoil_target.move_toward(Vector2.ZERO, deg_to_rad(_recoil_weapon.recoil_recovery_per_second) * recoil_recovery_multiplier * step)
		recoil_offset = recoil_offset.lerp(recoil_target, 1.0 - exp(-step / maxf(0.005, _recoil_weapon.recoil_response_seconds)))
		remaining -= step
	if recoil_target == Vector2.ZERO and recoil_offset.length_squared() < 0.0000000001:
		recoil_offset = Vector2.ZERO
	_apply_recoil()


func _apply_recoil() -> void:
	if camera != null:
		camera.rotation = Vector3(recoil_offset.x, recoil_offset.y, 0.0)

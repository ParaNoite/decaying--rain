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

	body.rotate_y(-mouse_motion.relative.x * sensitivity)
	head.rotate_x(-mouse_motion.relative.y * sensitivity)
	head.rotation.x = clampf(head.rotation.x, -pitch_limit, pitch_limit)
	return true


func update_motion_feedback(sprinting: bool, delta: float) -> void:
	if camera == null:
		return

	var target_fov: float = sprint_fov if sprinting else base_fov
	var blend: float = minf(1.0, fov_lerp_speed * delta)
	camera.fov = lerpf(camera.fov, target_fov, blend)
